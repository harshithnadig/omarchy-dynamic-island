import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: deskPage
  property var owner: null
  implicitHeight: pageContent.implicitHeight

  ColumnLayout {
    id: pageContent
    width: parent.width
    spacing: Style.space(12)

    // Current Focused Workspace Hero
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: deskHero.implicitHeight + Style.space(26)
      radius: Style.space(15)
      color: Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.12)
      border.color: Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.25)
      border.width: 1

      RowLayout {
        id: deskHero
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(12)

        Rectangle {
          Layout.preferredWidth: Style.space(48)
          Layout.preferredHeight: Style.space(48)
          radius: Style.space(14)
          color: Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.20)
          Text {
            anchors.centerIn: parent
            text: owner.focusedWorkspace
              ? (owner.focusedWorkspace.name || String(owner.focusedWorkspace.id)) : "—"
            color: owner.accent
            font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(3)
          Text {
            Layout.fillWidth: true
            text: owner.focusedWindow
              ? (owner.focusedWindow.title || "Focused Window")
              : "No focused window"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            color: owner.fg
          }
          Text {
            text: owner.currentWindows.length + " open "
              + (owner.currentWindows.length === 1 ? "window" : "windows")
              + " on this workspace"
            font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            color: Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.62)
          }
        }
      }
    }

    // Workspaces List
    Text {
      text: "Workspaces"
      font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      color: owner.fg
    }

    Flow {
      Layout.fillWidth: true
      spacing: Style.space(8)
      Repeater {
        model: owner.workspaceList
        Rectangle {
          required property var modelData
          width: Style.space(82)
          height: Style.space(56)
          radius: Style.space(11)
          color: modelData.focused
            ? Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.20) : owner.glass
          border.color: modelData.focused ? owner.accent : Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.1)
          border.width: modelData.focused ? 1.5 : 1

          Column {
            anchors.centerIn: parent
            spacing: Style.space(2)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.name || String(modelData.id)
              font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.DemiBold
              color: modelData.focused ? owner.accent : owner.fg
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: (modelData.toplevels ? modelData.toplevels.values.length : 0) + " windows"
              font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(10)
              color: Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.58)
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: owner.activateWorkspace(modelData)
          }
        }
      }
    }

    // Open Windows on Current Workspace
    Text {
      text: "Open Windows on Workspace"
      font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      color: owner.fg
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)
      Repeater {
        model: owner.currentWindows
        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          height: Style.space(52)
          radius: Style.space(10)
          color: modelData.activated
            ? Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.12) : owner.glass
          border.color: modelData.activated
            ? Qt.rgba(owner.accent.r, owner.accent.g, owner.accent.b, 0.3) : Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.08)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(10)

            Rectangle {
              Layout.preferredWidth: Style.space(8)
              Layout.preferredHeight: Style.space(8)
              radius: width / 2
              color: modelData.activated ? owner.accent : Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.25)
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text {
                Layout.fillWidth: true
                text: modelData.title
                  || (modelData.handle ? modelData.handle.appId : "")
                  || "Untitled Window"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: owner.fg
              }
              Text {
                text: modelData.handle
                  ? (modelData.handle.appId || "Application") : "Active application"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
                font.pixelSize: Style.space(10)
                color: Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.52)
              }
            }
            Text {
              text: "↗"
              font.pixelSize: Style.font.body
              color: owner.accent
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (typeof modelData.activate === "function") owner.activateWindow(modelData)
              else if (modelData.handle) owner.activateWindow(modelData.handle)
            }
          }
        }
      }

      Text {
        visible: owner.currentWindows.length === 0
        text: "This workspace is clear. No windows open."
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.family: owner.bar ? owner.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        color: Qt.rgba(owner.fg.r, owner.fg.g, owner.fg.b, 0.56)
      }
    }
  }
}

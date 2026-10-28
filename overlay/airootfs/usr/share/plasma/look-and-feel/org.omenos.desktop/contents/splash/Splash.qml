import QtQuick
import QtQuick.Window

// Splash OmenOS. ksplashqml menyetel properti `stage` (0..6), jadi QML ini
// sengaja hanya memakai QtQuick inti: tidak ada impor Plasma yang bisa berubah
// antarversi. Kalau gambar belum sempat dibuat, latar tetap hitam pekat.
Item {
    id: root
    property int stage: 0
    width: Screen.width
    height: Screen.height

    Rectangle {
        anchors.fill: parent
        color: "#07070a"
    }

    Image {
        anchors.fill: parent
        source: "/usr/share/omenos/wallpapers/omenos-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.45
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#8a07070a"
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Image {
            source: "/usr/share/omenos/brand/omenos-mark.svg"
            width: 168
            height: 168
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "OMENOS"
            color: "#f5f5f7"
            font.pixelSize: 44
            font.bold: true
            font.letterSpacing: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "menyiapkan sesi"
            color: "#9a9aa4"
            font.pixelSize: 13
            font.letterSpacing: 5
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(60, parent.height * 0.08)
        width: Math.min(parent.width * 0.32, 520)
        height: 4
        radius: 2
        color: "#24242c"

        Rectangle {
            height: parent.height
            radius: 2
            color: "#e00012"
            width: parent.width * Math.max(0.06, Math.min(1.0, root.stage / 6.0))
            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }
}

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

// Tema login OmenOS. Hanya memakai QtQuick inti + Controls, tanpa impor tema
// pihak ketiga, supaya tetap jalan di SDDM Qt6 (Arch) tanpa paket tambahan.
Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#07070a"

    property string statusText: ""

    function login() {
        if (passField.text.length === 0) {
            root.statusText = "Kata sandi belum diisi";
            passField.forceActiveFocus();
            return;
        }
        root.statusText = "";
        var user = userField.text.length > 0 ? userField.text : "omen";
        sddm.login(user, passField.text, sessionBox.currentIndex);
    }

    Image {
        anchors.fill: parent
        source: config.background ? config.background : "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Lapisan gelap supaya teks selalu terbaca, apa pun wallpaper-nya.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#cc050507" }
            GradientStop { position: 0.55; color: "#99050507" }
            GradientStop { position: 1.0; color: "#ee050507" }
        }
    }

    Text {
        id: clock
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 44
        anchors.rightMargin: 56
        text: Qt.formatTime(new Date(), "HH:mm")
        color: "#f5f5f7"
        font.pixelSize: 46
        font.weight: Font.Light
        font.letterSpacing: 2
    }

    Text {
        anchors.top: clock.bottom
        anchors.right: parent.right
        anchors.rightMargin: 58
        text: Qt.formatDate(new Date(), "dddd, dd MMMM yyyy")
        color: "#8e8e99"
        font.pixelSize: 13
        font.letterSpacing: 2
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "HH:mm");
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.width * 0.44, 540)
        height: form.implicitHeight + 64
        radius: 18
        color: "#d20b0b10"
        border.color: "#3de00012"
        border.width: 1

        ColumnLayout {
            id: form
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64
            spacing: 10

            Image {
                source: "/usr/share/omenos/brand/omenos-mark.svg"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 104
                Layout.preferredHeight: 104
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: "OMENOS"
                color: "#f5f5f7"
                font.pixelSize: 34
                font.bold: true
                font.letterSpacing: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "OMEN 15 \u00b7 ARCH LINUX"
                color: "#8e8e99"
                font.pixelSize: 11
                font.letterSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 18
            }

            Text {
                text: "PENGGUNA"
                color: "#85858f"
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            TextField {
                id: userField
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "omen"
                placeholderText: "nama pengguna"
                color: "#f5f5f7"
                placeholderTextColor: "#6c6c77"
                selectionColor: "#e00012"
                selectedTextColor: "#ffffff"
                leftPadding: 14
                rightPadding: 14
                font.pixelSize: 14
                background: Rectangle {
                    color: "#1a1a21"
                    border.color: userField.activeFocus ? "#e00012" : "#33333d"
                    border.width: 1
                    radius: 7
                }
                onAccepted: passField.forceActiveFocus()
            }

            Text {
                text: "KATA SANDI"
                color: "#85858f"
                font.pixelSize: 10
                font.letterSpacing: 2
                Layout.topMargin: 4
            }

            TextField {
                id: passField
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                placeholderText: "kata sandi"
                echoMode: TextInput.Password
                color: "#f5f5f7"
                placeholderTextColor: "#6c6c77"
                selectionColor: "#e00012"
                selectedTextColor: "#ffffff"
                leftPadding: 14
                rightPadding: 14
                font.pixelSize: 14
                background: Rectangle {
                    color: "#1a1a21"
                    border.color: passField.activeFocus ? "#e00012" : "#33333d"
                    border.width: 1
                    radius: 7
                }
                onAccepted: root.login()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10

                Text {
                    text: "SESI"
                    color: "#85858f"
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                ComboBox {
                    id: sessionBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    model: sessionModel
                    textRole: "name"
                    font.pixelSize: 13

                    background: Rectangle {
                        color: "#1a1a21"
                        border.color: "#33333d"
                        border.width: 1
                        radius: 7
                    }

                    contentItem: Text {
                        leftPadding: 12
                        rightPadding: 12
                        text: sessionBox.displayText
                        color: "#e9e9ee"
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    popup: Popup {
                        y: sessionBox.height + 4
                        width: sessionBox.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: sessionBox.popup.visible ? sessionBox.delegateModel : null
                            currentIndex: sessionBox.highlightedIndex
                        }

                        background: Rectangle {
                            color: "#16161c"
                            border.color: "#33333d"
                            radius: 7
                        }
                    }

                    delegate: ItemDelegate {
                        width: sessionBox.width
                        contentItem: Text {
                            text: model.name
                            color: highlighted ? "#ffffff" : "#c9c9d1"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: highlighted ? "#e00012" : "transparent"
                        }
                    }
                }
            }

            Button {
                id: loginButton
                text: "MASUK"
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.topMargin: 10
                onClicked: root.login()

                background: Rectangle {
                    color: loginButton.pressed ? "#8f0009" : "#e00012"
                    radius: 7
                }

                contentItem: Text {
                    text: loginButton.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                    font.letterSpacing: 3
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                text: root.statusText
                color: "#ff6b74"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Button {
                    id: powerButton
                    text: "MATIKAN"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    onClicked: sddm.powerOff()

                    background: Rectangle {
                        color: powerButton.pressed ? "#24242c" : "#141419"
                        border.color: "#2c2c35"
                        radius: 6
                    }

                    contentItem: Text {
                        text: powerButton.text
                        color: "#b9b9c3"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: rebootButton
                    text: "REBOOT"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    onClicked: sddm.reboot()

                    background: Rectangle {
                        color: rebootButton.pressed ? "#24242c" : "#141419"
                        border.color: "#2c2c35"
                        radius: 6
                    }

                    contentItem: Text {
                        text: rebootButton.text
                        color: "#b9b9c3"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: suspendButton
                    text: "SUSPEND"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    onClicked: sddm.suspend()

                    background: Rectangle {
                        color: suspendButton.pressed ? "#24242c" : "#141419"
                        border.color: "#2c2c35"
                        radius: 6
                    }

                    contentItem: Text {
                        text: suspendButton.text
                        color: "#b9b9c3"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56
        anchors.bottomMargin: 44
        text: "OMENOS \u00b7 PERFORMANCE, CONTROLLED"
        color: "#5f5f6a"
        font.pixelSize: 11
        font.letterSpacing: 3
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.statusText = "Login gagal \u2014 coba lagi";
            passField.text = "";
            passField.forceActiveFocus();
        }

        function onLoginSucceeded() {
            root.statusText = "";
        }

        function onInformationMessage(message) {
            root.statusText = message;
        }
    }

    Component.onCompleted: {
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) {
            sessionBox.currentIndex = sessionModel.lastIndex;
        }
        passField.forceActiveFocus();
    }
}

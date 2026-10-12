import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainersModelFilters 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property var containersDropDownRef: null

    property var apiAvailableProtocols: []
    property string apiCurrentProtocol: ""

    readonly property bool isApiProtocolSelectionVisible: ServersUiController.isDefaultServerFromApi && root.apiAvailableProtocols.length > 0
    readonly property bool isOutdatedAwgWarningVisible: drawer.isCollapsedStateActive()
                                                        && ServersUiController.defaultServerHasOutdatedAwgContainer

    function updateApiProtocolState() {
        if (ServersUiController.isDefaultServerFromApi) {
            root.apiAvailableProtocols = SubscriptionUiController.availableProtocols(ServersUiController.defaultServerId)
            root.apiCurrentProtocol = SubscriptionUiController.currentProtocol(ServersUiController.defaultServerId)
        } else {
            root.apiAvailableProtocols = []
            root.apiCurrentProtocol = ""
        }
    }

    function protocolDisplayName(protocol) {
        switch (protocol) {
        case "awg": return "AmneziaWG"
        case "vless": return "VLESS"
        default: return protocol
        }
    }

    Component.onCompleted: {
        root.updateApiProtocolState()
    }

    Connections {
        target: ServersUiController

        function onDefaultServerIdChanged() {
            root.updateApiProtocolState()
        }
    }

    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive) {
                if (drawer.isOpened) {
                    drawer.closeTriggered()
                }
                if (homeSplitTunnelingDrawer.isOpened) {
                    homeSplitTunnelingDrawer.closeTriggered()
                }
            }
        }
    }

    Connections {
        objectName: "pageControllerConnections"

        target: PageController

        function onRestorePageHomeState(isContainerInstalled) {
            drawer.openTriggered()
            if (isContainerInstalled && root.containersDropDownRef) {
                root.containersDropDownRef.rootButtonClickedFunction()
            }
        }
    }


    Item {
        objectName: "homeColumnItem"

        anchors.fill: parent
        anchors.bottomMargin: drawer.collapsedHeight

        ColumnLayout {
            objectName: "homeColumnLayout"

            anchors.fill: parent
            anchors.topMargin: 12 + PageController.safeAreaTopMargin
            anchors.bottomMargin: 16

            RowLayout {
                visible: MxPersonalBuild
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.topMargin: 8
                Label { text: ApplicationName; color: AmneziaStyle.color.textPrimary; font.pixelSize: 24; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Rectangle { width: 7; height: 7; radius: 4; color: ConnectionController.isConnected ? AmneziaStyle.color.vibrantGreen : AmneziaStyle.color.mutedGray }
                Label { text: ConnectionController.statusText; color: AmneziaStyle.color.textTertiary; font.pixelSize: 13 }
            }

            BasicButtonType {
                id: loggingButton
                objectName: "loggingButton"

                property bool isLoggingEnabled: SettingsController.isLoggingEnabled

                Layout.alignment: Qt.AlignHCenter

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                visible: isLoggingEnabled ? true : false
                text: qsTr("Logging enabled")

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    PageController.goToPage(PageEnum.PageSettingsLogging)
                }
            }

            BasicButtonType {
                id: devGatewayButton
                objectName: "devGatewayButton"

                property bool isDevGatewayEnabled: SettingsController.isDevGatewayEnv

                Layout.alignment: Qt.AlignHCenter

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                visible: SettingsController.isDevModeEnabled && isDevGatewayEnabled
                text: qsTr("Dev gateway enabled")

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    PageController.goToPage(PageEnum.PageDevMenu)
                }
            }

            ConnectButton {
                id: connectButton
                objectName: "connectButton"

                Layout.fillHeight: !MxPersonalBuild
                Layout.preferredHeight: MxPersonalBuild ? 190 : -1
                Layout.topMargin: MxPersonalBuild ? 16 : 0
                Layout.bottomMargin: MxPersonalBuild ? 12 : 0
                Layout.alignment: Qt.AlignCenter
                text: MxPersonalBuild && ConnectionController.isConnected ? qsTr("Disconnect") : ConnectionController.connectionStateText
            }

            GridLayout {
                visible: MxPersonalBuild
                columns: 2
                rowSpacing: 12
                columnSpacing: 24
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24

                ColumnLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: qsTr("PUBLIC IP"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 11; font.letterSpacing: 1.2 }
                    Label { objectName: "mxPublicIp"; text: ConnectionController.publicIp || "—"; color: AmneziaStyle.color.textPrimary; font.pixelSize: 20; font.family: "Menlo"; Accessible.name: qsTr("Public IP: ") + text }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: qsTr("COUNTRY"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 11; font.letterSpacing: 1 }
                    Label { objectName: "mxCountry"; text: ConnectionController.country || "—"; color: AmneziaStyle.color.textPrimary; font.pixelSize: 15; elide: Text.ElideRight; Layout.fillWidth: true; Accessible.name: qsTr("Country: ") + text }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: qsTr("DURATION"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 11; font.letterSpacing: 1 }
                    Label { objectName: "mxDuration"; text: ConnectionController.durationText; color: AmneziaStyle.color.textPrimary; font.pixelSize: 15; font.family: "Menlo"; Accessible.name: qsTr("Duration: ") + text }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: qsTr("DOWNLOAD"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 11; font.letterSpacing: 1 }
                    Label { objectName: "mxDownloadSpeed"; text: ConnectionController.downloadSpeedText; color: AmneziaStyle.color.textPrimary; font.pixelSize: 15; Accessible.name: qsTr("Download: ") + text }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: qsTr("UPLOAD"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 11; font.letterSpacing: 1 }
                    Label { objectName: "mxUploadSpeed"; text: ConnectionController.uploadSpeedText; color: AmneziaStyle.color.textPrimary; font.pixelSize: 15; Accessible.name: qsTr("Upload: ") + text }
                }
                RowLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Label { text: qsTr("Total transferred"); color: AmneziaStyle.color.textTertiary; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    Label { objectName: "mxTransferred"; text: ConnectionController.transferredText; color: AmneziaStyle.color.textPrimary; font.pixelSize: 13; Accessible.name: qsTr("Total transferred: ") + text }
                }
                Label {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    visible: ConnectionController.lookupStatus !== ""
                    text: ConnectionController.lookupStatus
                    color: AmneziaStyle.color.textTertiary
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
                BasicButtonType {
                    Layout.columnSpan: 2
                    visible: !ConnectionController.isConnectionInProgress && ConnectionController.publicIp === "" && ConnectionController.lookupStatus.indexOf("unavailable") >= 0
                    text: qsTr("Retry IP lookup")
                    implicitHeight: 32
                    defaultColor: AmneziaStyle.color.transparent
                    textColor: AmneziaStyle.color.goldenApricot
                    clickedFunc: function() { ConnectionController.refreshPublicIp() }
                }
            }

            BasicButtonType {
                id: splitTunnelingButton
                visible: !MxPersonalBuild
                objectName: "splitTunnelingButton"

                Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                leftPadding: 16
                rightPadding: 16

                implicitHeight: 36

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.mutedGray
                borderWidth: 0

                buttonTextLabel.lineHeight: 20
                buttonTextLabel.font.pixelSize: 14
                buttonTextLabel.font.weight: 500

                property bool isSplitTunnelingEnabled: IpSplitTunnelingController.isSplitTunnelingEnabled || AppSplitTunnelingController.isSplitTunnelingEnabled ||
                                                       ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

                text: isSplitTunnelingEnabled ? qsTr("Split tunneling enabled") : qsTr("Split tunneling disabled")

                leftImageSource: isSplitTunnelingEnabled ? "qrc:/images/controls/split-tunneling.svg" : ""
                leftImageColor: ""
                rightImageSource: "qrc:/images/controls/chevron-down.svg"

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()

                onClicked: {
                    homeSplitTunnelingDrawer.openTriggered()
                }

                HomeSplitTunnelingDrawer {
                    id: homeSplitTunnelingDrawer
                    objectName: "homeSplitTunnelingDrawer"

                    parent: root
                }
            }

            AdLabel {
                id: adLabel
                visible: !MxPersonalBuild

                Layout.fillWidth: true
                Layout.preferredHeight: adLabel.contentHeight
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 22
            }
        }
    }

    DrawerType2 {
        id: drawer
        objectName: "drawerProtocol"

        anchors.fill: parent

        collapsedStateContent: Item {
            objectName: "ProtocolDrawerCollapsedContent"

            implicitHeight: Qt.platform.os !== "ios" ? root.height * 0.9 : screen.height * 0.77
            Component.onCompleted: {
                drawer.expandedHeight = implicitHeight
            }

            ColumnLayout {
                id: collapsed
                objectName: "collapsedColumnLayout"

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Component.onCompleted: {
                    drawer.collapsedHeight = collapsed.implicitHeight
                }

                onImplicitHeightChanged: {
                    drawer.collapsedHeight = collapsed.implicitHeight
                }

                DividerType {
                    Layout.topMargin: 10
                    Layout.fillWidth: false
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 2
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                }

                RowLayout {
                    objectName: "rowLayout"

                    Layout.topMargin: 14
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                    spacing: 0

                    Connections {
                        objectName: "drawerConnections"

                        target: drawer
                        function onCursorEntered() {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = collapsedButtonChevron.hoveredColor
                                collapsedButtonHeader.opacity = 0.8
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }

                        function onCursorExited() {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = collapsedButtonChevron.defaultColor
                                collapsedButtonHeader.opacity = 1
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }

                        function onPressed(pressed, entered) {
                            if (drawer.isCollapsedStateActive) {
                                collapsedButtonChevron.backgroundColor = pressed ? collapsedButtonChevron.pressedColor : entered ? collapsedButtonChevron.hoveredColor : collapsedButtonChevron.defaultColor
                                collapsedButtonHeader.opacity = 0.7
                            } else {
                                collapsedButtonHeader.opacity = 1
                            }
                        }
                    }

                    Header1TextType {
                        id: collapsedButtonHeader
                        objectName: "collapsedButtonHeader"

                        Layout.maximumWidth: drawer.width - 48 - 18 - 12

                        maximumLineCount: 2
                        elide: Qt.ElideRight

                        text: ServersUiController.defaultServerName
                        horizontalAlignment: Qt.AlignHCenter

                        Behavior on opacity {
                            PropertyAnimation { duration: 200 }
                        }
                    }

                    ImageButtonType {
                        id: collapsedButtonChevron
                        objectName: "collapsedButtonChevron"
                        Accessible.name: qsTr("Show profiles")

                        Layout.leftMargin: 8

                        visible: drawer.isCollapsedStateActive()

                        hoverEnabled: false
                        image: "qrc:/images/controls/chevron-down.svg"
                        imageColor: AmneziaStyle.color.paleGray

                        icon.width: 18
                        icon.height: 18
                        backgroundRadius: 16
                        horizontalPadding: 4
                        topPadding: 4
                        bottomPadding: 3

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        onClicked: {
                            if (drawer.isCollapsedStateActive()) {
                                drawer.openTriggered()
                            }
                        }
                    }
                }

                RowLayout {
                    objectName: "rowLayoutLabel"
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: root.isOutdatedAwgWarningVisible
                                         ? 8
                                         : (root.isApiProtocolSelectionVisible ? 8 : (drawer.isCollapsedStateActive ? 44 : ServersUiController.isDefaultServerFromApi ? 61 : 16))
                    spacing: 0

                    BasicButtonType {
                        enabled: (ServersUiController.defaultServerImagePathCollapsed !== "") && drawer.isCollapsedStateActive
                        hoverEnabled: enabled

                        implicitHeight: 36

                        leftPadding: 16
                        rightPadding: 16

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite
                        disabledColor: AmneziaStyle.color.transparent
                        textColor: AmneziaStyle.color.mutedGray

                        buttonTextLabel.lineHeight: 16
                        buttonTextLabel.font.pixelSize: 13
                        buttonTextLabel.font.weight: 400

                        text: drawer.isCollapsedStateActive ? ServersUiController.defaultServerDescriptionCollapsed : ServersUiController.defaultServerDescriptionExpanded
                        leftImageSource: ServersUiController.defaultServerImagePathCollapsed
                        leftImageColor: ""
                        changeLeftImageSize: false

                        rightImageSource: hoverEnabled ? "qrc:/images/controls/chevron-down.svg" : ""

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        onClicked: {
                            ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)

                            if (ServersUiController.isServerFromApi(ServersUiController.processedServerId)) {
                                if (ServersUiController.isServerCountrySelectionAvailable(ServersUiController.processedServerId)) {
                                    PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
                                } else {
                                    PageController.showBusyIndicator(true)
                                    let result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                                    PageController.showBusyIndicator(false)
                                    if (!result) {
                                        return
                                    }

                                    PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
                                }
                            } else {
                                PageController.goToPage(PageEnum.PageSettingsServerInfo)
                            }
                        }
                    }
                }

                WarningType {
                    objectName: "outdatedContainerWarning"

                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 24

                    visible: root.isOutdatedAwgWarningVisible

                    backGroundColor: AmneziaStyle.color.transparent
                    iconPath: "qrc:/images/controls/alert-circle.svg"
                    imageColor: AmneziaStyle.color.goldenApricot
                    textColor: AmneziaStyle.color.goldenApricot
                    textString: qsTr("AmneziaWG 2.0 is outdated and no longer supported. Continued use requires a fresh installation of the AmneziaWG 3.1 container.")
                }

                RowLayout {
                    objectName: "protocolRowLayout"
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.bottomMargin: drawer.isCollapsedStateActive ? 44 : 61
                    spacing: 0

                    visible: root.isApiProtocolSelectionVisible

                    BasicButtonType {
                        id: protocolButton
                        objectName: "protocolButton"

                        enabled: root.apiAvailableProtocols.length > 1
                        hoverEnabled: enabled

                        implicitHeight: 36

                        leftPadding: 16
                        rightPadding: 16

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite
                        disabledColor: AmneziaStyle.color.transparent
                        textColor: AmneziaStyle.color.mutedGray

                        buttonTextLabel.lineHeight: 16
                        buttonTextLabel.font.pixelSize: 13
                        buttonTextLabel.font.weight: 400

                        text: root.apiAvailableProtocols.length > 1
                            ? root.protocolDisplayName(root.apiCurrentProtocol)
                            : root.protocolDisplayName(root.apiAvailableProtocols[0])
                        leftImageSource: "qrc:/images/controls/arrow-left-right.svg"
                        leftImageColor: AmneziaStyle.color.mutedGray

                        rightImageSource: enabled ? "qrc:/images/controls/chevron-down.svg" : ""

                        Keys.onEnterPressed: this.clicked()
                        Keys.onReturnPressed: this.clicked()

                        onClicked: {
                            if (ConnectionController.isConnectionInProgress) {
                                PageController.showNotificationMessage(qsTr("Unable change protocol while trying to make an active connection"))
                                return
                            }
                            if (ConnectionController.isConnected) {
                                PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                                return
                            }
                            protocolSelectionDrawer.openTriggered()
                        }
                    }
                }
            }

            ColumnLayout {
                id: serversMenuHeader
                objectName: "serversMenuHeader"

                anchors.top: collapsed.bottom
                anchors.right: parent.right
                anchors.left: parent.left

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: 8

                    visible: !ServersUiController.isDefaultServerFromApi

                    DropDownType {
                        id: containersDropDown
                        objectName: "containersDropDown"

                        Component.onCompleted: root.containersDropDownRef = containersDropDown

                        rootButtonImageColor: AmneziaStyle.color.midnightBlack
                        rootButtonBackgroundColor: AmneziaStyle.color.paleGray
                        rootButtonBackgroundHoveredColor: AmneziaStyle.color.mistyGray
                        rootButtonBackgroundPressedColor: AmneziaStyle.color.cloudyGray
                        rootButtonHoveredBorderColor: AmneziaStyle.color.transparent
                        rootButtonDefaultBorderColor: AmneziaStyle.color.transparent
                        rootButtonTextTopMargin: 8
                        rootButtonTextBottomMargin: 8

                        enabled: drawer.isOpened

                        text: ServersUiController.defaultServerDefaultContainerName
                        textColor: AmneziaStyle.color.midnightBlack
                        headerText: qsTr("VPN protocol")
                        headerBackButtonImage: "qrc:/images/controls/arrow-left.svg"

                        rootButtonClickedFunction: function() {
                            containersDropDown.openTriggered()
                        }

                        drawerParent: root

                        listView: HomeContainersListView {
                            id: containersListView
                            objectName: "containersListView"

                            rootWidth: root.width

                            Connections {
                                objectName: "rowLayoutConnections"

                                target: ServersUiController

                                function onDefaultServerIdChanged() {
                                    updateContainersModelFilters()
                                }
                            }

                            function updateContainersModelFilters() {
                                if (ServersUiController.isServerHasWriteAccess(ServersUiController.defaultServerId)) {
                                    proxyDefaultServerContainersModel.filters = ContainersModelFilters.getWriteAccessProtocolsListFilters()
                                } else {
                                    proxyDefaultServerContainersModel.filters = ContainersModelFilters.getReadAccessProtocolsListFilters()
                                }
                            }

                            model: SortFilterProxyModel {
                                id: proxyDefaultServerContainersModel
                                sourceModel: DefaultServerContainersModel

                                sorters: [
                                    RoleSorter { roleName: "isInstalled"; sortOrder: Qt.DescendingOrder }
                                ]
                            }

                            Component.onCompleted: updateContainersModelFilters()
                        }
                    }
                }

                Header2Type {
                    Layout.fillWidth: true
                    Layout.topMargin: 48
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    headerText: qsTr("Servers")
                }
            }

            ButtonGroup {
                id: serversRadioButtonGroup
                objectName: "serversRadioButtonGroup"
            }

            ServersListView {
                id: serversMenuContent
                objectName: "serversMenuContent"

                isFocusable: false

                Connections {
                    target: drawer

                    // this item shouldn't be focused when drawer is closed
                    function onIsOpenedChanged() {
                        serversMenuContent.isFocusable = drawer.isOpened
                    }
                }
            }
        }
    }

    DrawerType2 {
        id: protocolSelectionDrawer
        objectName: "protocolSelectionDrawer"

        anchors.fill: parent

        expandedStateContent: Item {
            id: protocolDrawerContainer

            implicitHeight: root.height * 0.5

            Component.onCompleted: {
                protocolSelectionDrawer.expandedHeight = protocolDrawerContainer.implicitHeight
            }

            ColumnLayout {
                id: protocolDrawerHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                BackButtonType {
                    id: protocolDrawerBackButton

                    Layout.fillWidth: true

                    backButtonImage: "qrc:/images/controls/arrow-left.svg"
                    backButtonFunction: function() { protocolSelectionDrawer.closeTriggered() }
                }

                Header2Type {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    headerText: qsTr("VPN protocol")
                }
            }

            ListViewType {
                id: protocolDrawerListView

                anchors.top: protocolDrawerHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 16

                model: root.apiAvailableProtocols

                ButtonGroup {
                    id: protocolDrawerButtonGroup
                }

                delegate: Item {
                    implicitWidth: protocolDrawerListView.width
                    implicitHeight: protocolDrawerDelegate.implicitHeight

                    ColumnLayout {
                        id: protocolDrawerDelegate

                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        VerticalRadioButton {
                            id: protocolDrawerRadioButton

                            Layout.fillWidth: true

                            text: root.protocolDisplayName(modelData)

                            ButtonGroup.group: protocolDrawerButtonGroup

                            checkable: !ConnectionController.isConnected
                            checked: modelData === root.apiCurrentProtocol

                            onClicked: {
                                protocolSelectionDrawer.closeTriggered()

                                if (modelData === root.apiCurrentProtocol) {
                                    return
                                }

                                if (ConnectionController.isConnected) {
                                    PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                                    return
                                }

                                PageController.showBusyIndicator(true)
                                ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
                                SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, modelData)
                                if (!SubscriptionUiController.updateServiceFromGateway(ServersUiController.defaultServerId, "", "", true)) {
                                    SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, root.apiCurrentProtocol)
                                }
                                root.updateApiProtocolState()
                                PageController.showBusyIndicator(false)
                            }

                            Keys.onEnterPressed: protocolDrawerRadioButton.clicked()
                            Keys.onReturnPressed: protocolDrawerRadioButton.clicked()
                        }

                        DividerType {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}

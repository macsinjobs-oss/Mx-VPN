import QtQuick

import Style 1.0

Text {
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    lineHeight: 21.6 + LanguageUiController.getLineHeightAppend()
    lineHeightMode: Text.FixedHeight

    color: AmneziaStyle.color.paleGray
    font.pixelSize: 18
    font.weight: 400
    font.family: "PT Root UI VF"

    wrapMode: Text.Wrap
}

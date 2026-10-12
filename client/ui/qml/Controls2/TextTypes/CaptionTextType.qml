import QtQuick

import Style 1.0

Text {
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    lineHeight: 16 + LanguageUiController.getLineHeightAppend()
    lineHeightMode: Text.FixedHeight

    color: AmneziaStyle.color.midnightBlack
    font.pixelSize: 13
    font.weight: 400
    font.family: "PT Root UI VF"
    font.letterSpacing: 0.02

    wrapMode: Text.Wrap
}

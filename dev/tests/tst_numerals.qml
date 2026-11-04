import QtQuick
import QtTest
import "../../overlay/Modules/Coreflame/Numerals.js" as Numerals

// Khaslana numbers his acts in Roman; the Flame Reaver pads to two digits.
TestCase {
    name: "Numerals"

    function test_roman_up_to_thirty_nine() {
        compare(Numerals.roman(1), "I");
        compare(Numerals.roman(4), "IV");
        compare(Numerals.roman(9), "IX");
        compare(Numerals.roman(14), "XIV");
        compare(Numerals.roman(39), "XXXIX");
    }

    function test_roman_falls_back_to_digits() {
        compare(Numerals.roman(0), "0");
        compare(Numerals.roman(40), "40");
    }

    function test_two_digits() {
        compare(Numerals.two(3), "03");
        compare(Numerals.two(12), "12");
        compare(Numerals.two(105), "105");
    }
}

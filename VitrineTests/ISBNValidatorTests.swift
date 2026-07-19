import XCTest
@testable import Vitrine

final class ISBNValidatorTests: XCTestCase {
    func testValidISBN10NormalizesAndConverts() throws {
        let result = try ISBNValidator.validate("0-14-118290-3")

        XCTAssertEqual(result.isbn10, "0141182903")
        XCTAssertEqual(result.isbn13, "9780141182902")
    }

    func testValidISBN13ConvertsToISBN10() throws {
        let result = try ISBNValidator.validate("9780141182902")

        XCTAssertEqual(result.isbn10, "0141182903")
        XCTAssertEqual(result.isbn13, "9780141182902")
    }

    func testInvalidCheckDigitIsRejectedLocally() {
        XCTAssertThrowsError(try ISBNValidator.validate("9780141182903"))
    }
}

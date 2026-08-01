import XCTest
@testable import Vitrine

final class FilenameMetadataParserRefinementTests: XCTestCase {
    private let parser = FilenameMetadataParser(engine: .v2)

    func testLexicalWordsAndSurnamesBeginningWithVolAreNotVolumes() {
        let lexical = parser.suggestions(
            from: "Les soucoupes volantes ont aterri, par Desmond Leslie et George Adamski, Collection J'AI LU:L'aventure mystérieuse, 1971 (1970) 306p"
        )
        let surname = parser.suggestions(
            from: "Saint-Petersbourg, \"A Cultural History par Solomon Volkov, Simon & Schuster, New York 1997 624p. ill"
        )

        XCTAssertNil(lexical.volumeDescription)
        XCTAssertNil(surname.volumeDescription)
        XCTAssertEqual(surname.authors?.value, ["Solomon Volkov"])
    }

    func testStructuralVolumeFormsRemainSupported() {
        let abbreviated = parser.suggestions(
            from: "Bulletin des Recherches Historiques, Le, publié par Pierre-Georges Roy, Vol. 41, Lévis 1935 768p"
        )
        let descriptive = parser.suggestions(
            from: "Picture Gallery of Canadian History, The, Vol, 1 Discovery to 1763, The Ryerson Press, Toronto 1949 268p"
        )
        let italian = parser.suggestions(
            from: "Storia delle Famiglie Romane, par Teodoro Amayden, Volume Primo con note ed aggiunte, Edizioni Romane Colosseum, 1987 464p"
        )

        XCTAssertEqual(abbreviated.volumeDescription?.value, "Vol. 41")
        XCTAssertEqual(descriptive.volumeDescription?.value, "Vol, 1 Discovery to 1763")
        XCTAssertEqual(italian.volumeDescription?.value, "Volume Primo con note ed aggiunte")
    }

    func testExplicitCollectionOutranksPublisherFallback() {
        let soucoupes = parser.suggestions(
            from: "Les soucoupes volantes ont aterri, par Desmond Leslie et George Adamski, Collection J'AI LU:L'aventure mystérieuse, 1971 (1970) 306p"
        )
        let gide = parser.suggestions(
            from: "Gide II -Journal 1939-1949 NRF, Gallimard, Collection La Pléïda 1954 1280p."
        )
        let berko = parser.suggestions(
            from: "Paul Leduc 1876:1943, Patrick et Viviane Berko, par Stéphane Rey, Collection Berko 1990 167p. ill. avec jaquette"
        )

        XCTAssertNil(soucoupes.publisher)
        XCTAssertEqual(soucoupes.collectionName?.value, "J'AI LU")
        XCTAssertEqual(gide.publisher?.value, "Gallimard")
        XCTAssertEqual(gide.collectionName?.value, "La Pléïda")
        XCTAssertNil(berko.publisher)
        XCTAssertEqual(berko.collectionName?.value, "Berko")
    }

    func testPublisherEndingInPlaceNameIsNotSplitWithoutStructuralBoundary() {
        let suggestion = parser.suggestions(
            from: "Sissi, impératrice d'Autriche, par Élisabeth Burnat, Le Livre de Poche:Éditions de Paris, 1976 (1957) 253p"
        )

        XCTAssertEqual(suggestion.publisher?.value, "Éditions de Paris")
        XCTAssertNil(suggestion.publicationPlace)
        XCTAssertEqual(suggestion.collectionName?.value, "Le Livre de Poche")
    }

    func testExactEditonsCorrectionRestoresPublisherAndDelimitedPlace() {
        let source = "Conjugar es fácil en español, par Alfredo Gonzalez Hermoso, Éditons Edelsa, Madrid 1996 222p"
        let suggestion = parser.suggestions(from: source)

        XCTAssertEqual(suggestion.publisher?.value, "Éditions Edelsa")
        XCTAssertEqual(suggestion.publicationPlace?.value, "Madrid")
        XCTAssertEqual(
            suggestion.publisher?.sourceSpan.map { String(Array(source)[$0]) },
            "Éditons Edelsa"
        )
    }

    func testGracieuseteCorrectionProducesProvenanceOnly() {
        let source = "Funérailles chrétiennes, Gracieu seté de L. Gaston Gaudet 32p"
        let suggestion = parser.suggestions(from: source)

        XCTAssertNil(suggestion.authors)
        XCTAssertNil(suggestion.publisher)
        XCTAssertNil(suggestion.collectionName)
        XCTAssertEqual(suggestion.title?.value, "Funérailles chrétiennes")
        XCTAssertTrue(suggestion.descriptiveNotes?.value.contains("Gracieuseté de L. Gaston Gaudet") == true)
        XCTAssertEqual(
            suggestion.descriptiveNotes?.sourceSpan.map { String(Array(source)[$0]) },
            "Gracieu seté de L. Gaston Gaudet "
        )
    }

    func testBrokenPartieDoesNotCreateSpuriousAuthor() {
        let suggestion = parser.suggestions(
            from: "Église du Canada, L', -Depuis Monseigneur de Laval, 1re par tie Mgr de Saint-Vallier, pa r l'abbé Auguste Gosselin, Typ. Laflamme & Proulx, Québec, 1911 503p"
        )

        XCTAssertEqual(suggestion.authors?.value, ["l'abbé Auguste Gosselin"])
        XCTAssertFalse(suggestion.authors?.value.contains("tie Mgr de Saint-Vallier") == true)
    }

    func testContributorCaptureStopsAtUnpunctuatedPublisherMarker() {
        let source = "Essai sur les Baillis, par Maurice Veyrat, Préface de René Herval Éditions Maugard, Rouen 1953 303p"
        let suggestion = parser.suggestions(from: source)

        XCTAssertEqual(suggestion.contributors?.value, [
            .init(name: "René Herval", roles: [.preface])
        ])
        XCTAssertEqual(suggestion.publisher?.value, "Éditions Maugard")
        XCTAssertEqual(suggestion.publicationPlace?.value, "Rouen")
        XCTAssertEqual(
            suggestion.contributors?.sourceSpan.map { String(Array(source)[$0]) },
            "Préface de René Herval"
        )
    }

    func testContributorSurnameMatchingPublisherWordIsPreserved() {
        let suggestion = parser.suggestions(
            from: "Essai, par Maurice Veyrat, Préface de Alice Press, Éditions Maugard, Rouen 1953 303p"
        )

        XCTAssertEqual(suggestion.contributors?.value, [
            .init(name: "Alice Press", roles: [.preface])
        ])
        XCTAssertEqual(suggestion.publisher?.value, "Éditions Maugard")
    }

    func testTopLevelPlaceSurvivesBlockedPublisherFallback() {
        let suggestion = parser.suggestions(
            from: "Bulletin des Recherches Historiques, Le, publié par Pierre-Georges Roy, Vol. 41, Lévis 1935 768p"
        )

        XCTAssertNil(suggestion.publisher)
        XCTAssertEqual(suggestion.publicationPlace?.value, "Lévis")
    }

    func testQuotedSubtitleWithResponsibilityIsNotACollection() {
        let suggestion = parser.suggestions(
            from: "Essai sur les Baillis, \"Documents et Portraits inédits\" par Maurice Veyrat, Préface de René Herval Éditions Maugard, Rouen 1953 303p"
        )

        XCTAssertEqual(suggestion.title?.value, "Essai sur les Baillis")
        XCTAssertEqual(suggestion.subtitle?.value, "Documents et Portraits inédits")
        XCTAssertNil(suggestion.collectionName)
    }

    func testCommaBeforeQuotedTextEstablishesSubtitleRatherThanSubjectHeading() {
        let suggestion = parser.suggestions(
            from: "Vita Romana, \"La vie quotidienne dans la Rome antique, par Ugo Enrico Paoli, éd. Desclée de Brouwer 1960 495p"
        )

        XCTAssertEqual(suggestion.title?.value, "Vita Romana")
        XCTAssertEqual(suggestion.subtitle?.value, "La vie quotidienne dans la Rome antique")
    }
}

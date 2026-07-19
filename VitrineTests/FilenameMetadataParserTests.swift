import XCTest
@testable import Vitrine

final class FilenameMetadataParserTests: XCTestCase {
    private let parser = FilenameMetadataParser()

    func testRestoresTrailingArticleAndExtractsEditionDetails() {
        let suggestion = parser.suggestions(
            from: "Japon, Le, Dictionnaire et civilisation, par Louis Frédéric, \"Bouquins\" Éditions Robert Laffont, 1996 1419p"
        )

        XCTAssertEqual(suggestion.title?.value, "Le Japon")
        XCTAssertEqual(suggestion.subtitle?.value, "Dictionnaire et civilisation")
        XCTAssertEqual(suggestion.authors?.value, ["Louis Frédéric"])
        XCTAssertEqual(suggestion.publicationDate?.value, "1996")
        XCTAssertEqual(suggestion.pageCount?.value, 1419)
    }

    func testTwoYearsBecomePublicationAndOriginalPublication() {
        let suggestion = parser.suggestions(
            from: "La nature du prince, récit de Roger Peyrefitte, Le Livre de Poche, Flammarion 1967 (1963) 190p"
        )

        XCTAssertEqual(suggestion.publicationDate?.value, "1967")
        XCTAssertEqual(suggestion.originalPublicationDate?.value, "1963")
        XCTAssertEqual(suggestion.pageCount?.value, 190)
    }

    func testRestoresEnglishTrailingArticle() {
        let suggestion = parser.suggestions(from: "Hammonds of Redcliffe, The, edited by Carol Bleser, Oxford University Press, 1981 421p")

        XCTAssertEqual(suggestion.title?.value, "The Hammonds of Redcliffe")
        XCTAssertEqual(suggestion.authors?.value, ["Carol Bleser"])
    }

    func testHistoricalYearInsideTitleIsNotOriginalPublicationYear() {
        let suggestion = parser.suggestions(
            from: "Yalta ou la partage du monde (11 février 1945), par Arthur Conte, Éditions J'AI LU,1969 445p"
        )

        XCTAssertEqual(suggestion.publicationDate?.value, "1969")
        XCTAssertNil(suggestion.originalPublicationDate)
    }

    func testQuotedSubtitleAndRoleMarkerWithoutComma() {
        let suggestion = parser.suggestions(
            from: "La maison traditionnelle au Québec, \"Construction Inventaire Restauration\", par Michel Lessard et Gilles Vilandré, Les Éditions de l'Homme, 1974 493p"
        )

        XCTAssertEqual(suggestion.title?.value, "La maison traditionnelle au Québec")
        XCTAssertEqual(suggestion.subtitle?.value, "Construction Inventaire Restauration")
        XCTAssertEqual(suggestion.authors?.value, ["Michel Lessard", "Gilles Vilandré"])
    }

    func testEditorMarkerWithoutLeadingCommaAndVolume() {
        let suggestion = parser.suggestions(
            from: "Lisle Letters, The edited by Muriel St Clare Byrne, Forword by Hugh Trevor-Roper, Penguin Books, 1983 (1981) 549p"
        )

        XCTAssertEqual(suggestion.title?.value, "The Lisle Letters")
        XCTAssertEqual(suggestion.authors?.value, ["Muriel St Clare Byrne"])
        XCTAssertEqual(suggestion.originalPublicationDate?.value, "1981")
    }

    func testFrenchElidedAndSimpleTrailingArticles() {
        let egypt = parser.suggestions(
            from: "Égypte française au jour le jour 1798-1801, L', par Jean-Joël Brégeon, Librairie Académique Perrin, Paris 1991 444p"
        )
        let genealogy = parser.suggestions(
            from: "généalogie, La, par Pierre Durye, Presses Universitaires de France, 1971 (1961) 128p"
        )

        XCTAssertEqual(egypt.title?.value, "L'Égypte française au jour le jour 1798-1801")
        XCTAssertEqual(egypt.publicationDate?.value, "1991")
        XCTAssertEqual(genealogy.title?.value, "La généalogie")
    }

    func testAuthorlessAlbumKeepsLocationAndCustodiansInTitle() {
        let suggestion = parser.suggestions(
            from: "Album delle catacombe di S. Callisto, Via Appia Antica 52, R.R. P.P. Trappisti, Custodi, en français et en italien, s/d non-paginé ill"
        )

        XCTAssertEqual(suggestion.title?.value, "Album delle catacombe di S. Callisto, Via Appia Antica 52, R.R. P.P. Trappisti, Custodi")
        XCTAssertNil(suggestion.authors)
        XCTAssertEqual(suggestion.languageCodes?.value, ["fr", "it"])
        XCTAssertEqual(suggestion.paginationStatus?.value, .nonPaginated)
        XCTAssertEqual(suggestion.physicalAttributes?.value, [.illustrated])
    }

    func testCompilerAndAnnotatorAreContributorsNotAuthors() {
        let suggestion = parser.suggestions(
            from: "Éloquence indienne, Textes. choisis, présentés et annotés par André Vachon, Collection \"Classiquea canadien\", Éditions Fides Ottawa 1968 96p"
        )

        XCTAssertEqual(suggestion.title?.value, "Éloquence indienne")
        XCTAssertNil(suggestion.authors)
        XCTAssertEqual(suggestion.contributors?.value, [
            .init(name: "André Vachon", roles: [.compiler, .editor, .annotator])
        ])
        XCTAssertEqual(suggestion.collectionName?.value, "Classiques canadiens")
        XCTAssertEqual(suggestion.publisher?.value, "Éditions Fides")
        XCTAssertEqual(suggestion.publicationPlace?.value, "Ottawa")
    }

    func testPrivateCollectionOwnersAreNotAuthorsAndCollectionBerkoIsPublisher() {
        let suggestion = parser.suggestions(
            from: "Paul Leduc 1876/1943, Patrick et Viviane Berko, par Stéphane Rey, Collection Berko 1990 167p. ill. avec jaquette"
        )

        XCTAssertEqual(suggestion.title?.value, "Paul Leduc 1876/1943")
        XCTAssertEqual(suggestion.authors?.value, ["Stéphane Rey"])
        XCTAssertEqual(suggestion.publisher?.value, "Collection Berko")
        XCTAssertNil(suggestion.collectionName)
        XCTAssertEqual(suggestion.publicationDate?.value, "1990")
        XCTAssertEqual(suggestion.physicalAttributes?.value, [.illustrated, .dustJacket])
        XCTAssertTrue(suggestion.descriptiveNotes?.value.contains("Patrick et Viviane Berko") == true)
    }

    func testHouseOfFarneseExtractsRichEditionMetadata() {
        let suggestion = parser.suggestions(
            from: "Farnese, The House of, \"A Portrait of a Great Family of the Renaissance, par Giovanna R. Solari, translated by Simona Morini and Frederic Tuten, Doubleday & Company, Inc., Garden City, New York 1968 (1964) 310p. ill. avec jaquette"
        )

        XCTAssertEqual(suggestion.title?.value, "The House of Farnese")
        XCTAssertEqual(suggestion.subtitle?.value, "A Portrait of a Great Family of the Renaissance")
        XCTAssertEqual(suggestion.authors?.value, ["Giovanna R. Solari"])
        XCTAssertEqual(suggestion.translators?.value, ["Simona Morini", "Frederic Tuten"])
        XCTAssertEqual(suggestion.publicationPlace?.value, "Garden City, New York")
        XCTAssertEqual(suggestion.publicationDate?.value, "1968")
        XCTAssertEqual(suggestion.originalPublicationDate?.value, "1964")
        XCTAssertEqual(suggestion.pageCount?.value, 310)
        XCTAssertEqual(suggestion.physicalAttributes?.value, [.illustrated, .dustJacket])
    }

    func testInvasionExtractsTomeTranslationMapsAndSlipcase() {
        let suggestion = parser.suggestions(
            from: "Invasion du Canada, L', par Pierre Berton tome 1 Les Américains attaquent, 1812-1813, traduit de l'anglais par Michèle Venet et Jean Lévesque, Éditions de l'Homme, 1981 (1980) 372p. avec qq cartes, dans un boitier"
        )

        XCTAssertEqual(suggestion.title?.value, "L'Invasion du Canada")
        XCTAssertEqual(suggestion.authors?.value, ["Pierre Berton"])
        XCTAssertEqual(suggestion.translators?.value, ["Michèle Venet", "Jean Lévesque"])
        XCTAssertEqual(suggestion.volumeDescription?.value, "tome 1")
        XCTAssertEqual(suggestion.originalLanguageCode?.value, "en")
        XCTAssertEqual(suggestion.physicalAttributes?.value, [.maps, .slipcase])
    }

    func testAuthorFirstDanielRopsAndBibliographicNumbering() {
        let suggestion = parser.suggestions(
            from: "Daniel-Rops de l'Académie française, 6.1 L'Église des révolutions -en face de nouveaux destins, Les Grandes études historiques, Librairie Arthème Fayard 1962 (1960) 1045p"
        )

        XCTAssertEqual(suggestion.title?.value, "L'Église des révolutions")
        XCTAssertEqual(suggestion.subtitle?.value, "en face de nouveaux destins")
        XCTAssertEqual(suggestion.authors?.value, ["Daniel-Rops"])
        XCTAssertEqual(suggestion.volumeDescription?.value, "6.1")
        XCTAssertEqual(suggestion.collectionName?.value, "Les Grandes études historiques")
        XCTAssertEqual(suggestion.publisher?.value, "Librairie Arthème Fayard")
    }

    func testListOrdinalIsRemovedButConfirmedComplexTitleIsReconstructed() {
        let suggestion = parser.suggestions(
            from: "30) Capitol, We the People -The Story of the United States, The National Geographic Society, Washington D.C., 1963 144p. ill"
        )

        XCTAssertEqual(suggestion.title?.value, "We the People: The Story of the United States Capitol")
        XCTAssertEqual(suggestion.publisher?.value, "The National Geographic Society")
        XCTAssertEqual(suggestion.publicationPlace?.value, "Washington D.C.")
    }

    func testConfirmedUnlabelledAndDualRoleAuthors() {
        let guest = parser.suggestions(from: "Be My Guest, Conrad N. Hilton, A Fireside Book/Simon & Schuster, 1994 (1957) 288p. ill")
        let establishment = parser.suggestions(
            from: "Canadian Establishment, Debrett's Illustrated Guide to The, par Peter C. Newman, general editor, éd. Methuen 1983 408p. ill. dédicace de l'auteur, avec jaquette"
        )

        XCTAssertEqual(guest.title?.value, "Be My Guest")
        XCTAssertEqual(guest.authors?.value, ["Conrad N. Hilton"])
        XCTAssertEqual(establishment.title?.value, "Debrett's Illustrated Guide to the Canadian Establishment")
        XCTAssertEqual(establishment.authors?.value, ["Peter C. Newman"])
        XCTAssertEqual(establishment.contributors?.value, [
            .init(name: "Peter C. Newman", roles: [.generalEditor])
        ])
    }

    func testConfirmedTitleInversionsAndListArtifactRemoval() {
        let directory = parser.suggestions(from: "Drummondville, Bottin Touristique & Historique de, 1975 88p. ill")
        let bade = parser.suggestions(from: "Bade, Le sang de, par Georges Martin 1982 (fascicule 141pages doubles)")
        let aubry = parser.suggestions(
            from: "François X. Aubry \"Trader, Trailmaker and Voyageur in the Southwest 1846-1854, by Donald Chaput, The Arthur H. Clark Company, Glendale CA 1975 249p. ill. et cartes"
        )

        XCTAssertEqual(directory.title?.value, "Bottin Touristique & Historique de Drummondville")
        XCTAssertNil(directory.authors)
        XCTAssertNil(directory.publisher)
        XCTAssertEqual(bade.title?.value, "Le sang de Bade")
        XCTAssertEqual(bade.authors?.value, ["Georges Martin"])
        XCTAssertEqual(bade.physicalAttributes?.value, [.doublePages])
        XCTAssertEqual(aubry.title?.value, "François X. Aubry: Trader, Trailmaker and Voyageur in the Southwest 1846-1854")
        XCTAssertEqual(aubry.authors?.value, ["Donald Chaput"])
    }

    func testForewordCompilerAndEditorDirectorRoles() {
        let property = parser.suggestions(
            from: "A Valuable Property, The life story of Michael Todd, by Michael Todd Jr et Susan McCarthy Todd Foreword by Elizabeth Taylor, Paperjacks Ltd, 1983 369p. ill"
        )
        let bossuet = parser.suggestions(from: "Bossuet Oeuvres choisies... par J. Calvet, onzième édition librairie A. Hatier, Paris 1930 725p. ill")
        let bulletin = parser.suggestions(from: "Bulletin des Recherches Historiques, Le, publié par Pierre-Georges Roy, Vol. 41, Lévis 1935 768p")

        XCTAssertEqual(property.title?.value, "A Valuable Property")
        XCTAssertEqual(property.subtitle?.value, "The life story of Michael Todd")
        XCTAssertEqual(property.authors?.value, ["Michael Todd Jr", "Susan McCarthy Todd"])
        XCTAssertEqual(property.contributors?.value, [.init(name: "Elizabeth Taylor", roles: [.foreword])])
        XCTAssertEqual(bossuet.title?.value, "Œuvres choisies...")
        XCTAssertEqual(bossuet.authors?.value, ["Bossuet"])
        XCTAssertEqual(bossuet.contributors?.value, [.init(name: "J. Calvet", roles: [.compiler, .editor])])
        XCTAssertEqual(bulletin.title?.value, "Le Bulletin des Recherches Historiques")
        XCTAssertNil(bulletin.authors)
        XCTAssertEqual(bulletin.contributors?.value, [.init(name: "Pierre-Georges Roy", roles: [.editorDirector])])
    }

    func testQuotedAndHyphenatedSubtitlesAreSeparated() {
        let twilight = parser.suggestions(
            from: "Twilight of the Wagners \"The Unveiling of a Family's Legacy\", par Gottfried Wagner, English Translation by Della Couling, éd. Picador USA, New York 1997 310p. ill. avec jaquette"
        )
        let bescherelle = parser.suggestions(
            from: "Bescherelle -El arte de conjugar en español, Diccionario de 12 000 verbos, par Francis Mateo et Antonio J. Rojo Sastre, Éd. HMH, 2002 (1998) 251p"
        )

        XCTAssertEqual(twilight.title?.value, "Twilight of the Wagners")
        XCTAssertEqual(twilight.subtitle?.value, "The Unveiling of a Family's Legacy")
        XCTAssertEqual(twilight.translators?.value, ["Della Couling"])
        XCTAssertEqual(bescherelle.title?.value, "Bescherelle")
        XCTAssertEqual(bescherelle.subtitle?.value, "El arte de conjugar en español, Diccionario de 12 000 verbos")
    }
}

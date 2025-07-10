/*
 * CONTEXT & PURPOSE:
 * AddressParserTests provides comprehensive unit tests for the AddressParser utility.
 * It tests all static methods with various edge cases to ensure reliable address
 * parsing and manipulation throughout the application.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial implementation
 *   - Tests all static methods in AddressParser
 *   - Covers edge cases: empty strings, malformed addresses, international formats
 *   - Tests special characters and various street suffix formats
 *   - Ensures 100% code coverage for pure functions
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
@testable import C11SHouse

class AddressParserTests: XCTestCase {
    
    // MARK: - parseComponents(from:) Tests
    
    func testParseComponents_ValidUSAddress() {
        let address = "123 Main Street, New York, NY 10001"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "123 Main Street")
        XCTAssertEqual(result?.city, "New York")
        XCTAssertEqual(result?.state, "NY")
        XCTAssertEqual(result?.postalCode, "10001")
        XCTAssertEqual(result?.country, "United States")
    }
    
    func testParseComponents_ValidAddressWithCountry() {
        let address = "456 Oak Avenue, Los Angeles, CA 90001, USA"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "456 Oak Avenue")
        XCTAssertEqual(result?.city, "Los Angeles")
        XCTAssertEqual(result?.state, "CA")
        XCTAssertEqual(result?.postalCode, "90001")
        XCTAssertEqual(result?.country, "USA")
    }
    
    func testParseComponents_AddressWithExtraSpaces() {
        let address = "  789 Pine Road  ,  Chicago  ,  IL  60601  "
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "789 Pine Road")
        XCTAssertEqual(result?.city, "Chicago")
        XCTAssertEqual(result?.state, "IL")
        XCTAssertEqual(result?.postalCode, "60601")
        XCTAssertEqual(result?.country, "United States")
    }
    
    func testParseComponents_InternationalFormat() {
        let address = "10 Downing Street, Westminster, London SW1A 2AA, United Kingdom"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "10 Downing Street")
        XCTAssertEqual(result?.city, "Westminster")
        XCTAssertEqual(result?.state, "London")
        XCTAssertEqual(result?.postalCode, "SW1A")
        XCTAssertEqual(result?.country, "United Kingdom")
    }
    
    func testParseComponents_StateWithoutPostalCode() {
        let address = "123 Main St, City, State"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "123 Main St")
        XCTAssertEqual(result?.city, "City")
        XCTAssertEqual(result?.state, "State")
        XCTAssertEqual(result?.postalCode, "")
        XCTAssertEqual(result?.country, "United States")
    }
    
    func testParseComponents_EmptyString() {
        let result = AddressParser.parseComponents(from: "")
        XCTAssertNil(result)
    }
    
    func testParseComponents_SingleComponent() {
        let result = AddressParser.parseComponents(from: "123 Main Street")
        XCTAssertNil(result)
    }
    
    func testParseComponents_TwoComponents() {
        let result = AddressParser.parseComponents(from: "123 Main Street, New York")
        XCTAssertNil(result)
    }
    
    func testParseComponents_SpecialCharacters() {
        let address = "123 O'Brien Street, Saint Mary's, MO 63673"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "123 O'Brien Street")
        XCTAssertEqual(result?.city, "Saint Mary's")
        XCTAssertEqual(result?.state, "MO")
        XCTAssertEqual(result?.postalCode, "63673")
    }
    
    // MARK: - parseAddress(_:coordinate:) Tests
    
    func testParseAddress_ValidAddressWithCoordinate() {
        let coordinate = Coordinate(latitude: 40.7128, longitude: -74.0060)
        let address = AddressParser.parseAddress("123 Main St, New York, NY 10001", coordinate: coordinate)
        
        XCTAssertNotNil(address)
        XCTAssertEqual(address?.street, "123 Main St")
        XCTAssertEqual(address?.city, "New York")
        XCTAssertEqual(address?.state, "NY")
        XCTAssertEqual(address?.postalCode, "10001")
        XCTAssertEqual(address?.country, "United States")
        XCTAssertEqual(address?.coordinate.latitude, 40.7128)
        XCTAssertEqual(address?.coordinate.longitude, -74.0060)
    }
    
    func testParseAddress_ValidAddressWithoutCoordinate() {
        let address = AddressParser.parseAddress("456 Oak Ave, Chicago, IL 60601")
        
        XCTAssertNotNil(address)
        XCTAssertEqual(address?.street, "456 Oak Ave")
        XCTAssertEqual(address?.city, "Chicago")
        XCTAssertEqual(address?.state, "IL")
        XCTAssertEqual(address?.postalCode, "60601")
        XCTAssertEqual(address?.coordinate.latitude, 0)
        XCTAssertEqual(address?.coordinate.longitude, 0)
    }
    
    func testParseAddress_InvalidAddress() {
        let address = AddressParser.parseAddress("Invalid Address")
        XCTAssertNil(address)
    }
    
    func testParseAddress_EmptyString() {
        let address = AddressParser.parseAddress("")
        XCTAssertNil(address)
    }
    
    // MARK: - extractStreetName(from:) Tests
    
    func testExtractStreetName_WithStreetSuffix() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Main Street"), "Main")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Oak Avenue"), "Oak")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 Pine Road"), "Pine")
        XCTAssertEqual(AddressParser.extractStreetName(from: "101 Elm Boulevard"), "Elm")
        XCTAssertEqual(AddressParser.extractStreetName(from: "202 Cedar Lane"), "Cedar")
        XCTAssertEqual(AddressParser.extractStreetName(from: "303 Maple Drive"), "Maple")
    }
    
    func testExtractStreetName_WithAbbreviatedSuffix() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Main St"), "Main")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Oak Ave"), "Oak")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 Pine Rd"), "Pine")
        XCTAssertEqual(AddressParser.extractStreetName(from: "101 Elm Blvd"), "Elm")
        XCTAssertEqual(AddressParser.extractStreetName(from: "202 Cedar Ln"), "Cedar")
        XCTAssertEqual(AddressParser.extractStreetName(from: "303 Maple Dr"), "Maple")
    }
    
    func testExtractStreetName_WithPeriodInSuffix() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Main St."), "Main")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Oak Ave."), "Oak")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 Pine Rd."), "Pine")
    }
    
    func testExtractStreetName_MultipleSuffixes() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Court Street"), "Court")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Park Place"), "Park")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 Circle Drive"), "Circle")
    }
    
    func testExtractStreetName_NoSuffix() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Broadway"), "Broadway")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Fifth"), "Fifth")
    }
    
    func testExtractStreetName_MixedCase() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Main STREET"), "Main")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 OAK avenue"), "OAK")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 pine RoAd"), "pine")
    }
    
    func testExtractStreetName_SpecialCharacters() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 O'Brien Street"), "O'Brien")
        XCTAssertEqual(AddressParser.extractStreetName(from: "456 Saint Mary's Avenue"), "Saint Mary's")
        XCTAssertEqual(AddressParser.extractStreetName(from: "789 Martin Luther King Jr. Boulevard"), "Martin Luther King Jr.")
    }
    
    func testExtractStreetName_EmptyString() {
        XCTAssertEqual(AddressParser.extractStreetName(from: ""), "")
    }
    
    func testExtractStreetName_OnlyNumbers() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 456 789"), "")
    }
    
    func testExtractStreetName_OnlyStreetSuffix() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "Street"), "")
        XCTAssertEqual(AddressParser.extractStreetName(from: "Avenue"), "")
        XCTAssertEqual(AddressParser.extractStreetName(from: "123 Street"), "")
    }
    
    func testExtractStreetName_ExtraSpaces() {
        XCTAssertEqual(AddressParser.extractStreetName(from: "  123   Main   Street  "), "Main")
        XCTAssertEqual(AddressParser.extractStreetName(from: "\t456\tOak\tAvenue\t"), "Oak")
    }
    
    // MARK: - extractStreetComponent(from:) Tests
    
    func testExtractStreetComponent_FullAddress() {
        let address = "123 Main Street, New York, NY 10001"
        XCTAssertEqual(AddressParser.extractStreetComponent(from: address), "123 Main Street")
    }
    
    func testExtractStreetComponent_MultipleCommas() {
        let address = "456 Oak Avenue, Los Angeles, CA 90001, USA"
        XCTAssertEqual(AddressParser.extractStreetComponent(from: address), "456 Oak Avenue")
    }
    
    func testExtractStreetComponent_NoComma() {
        let address = "789 Pine Road"
        XCTAssertEqual(AddressParser.extractStreetComponent(from: address), "789 Pine Road")
    }
    
    func testExtractStreetComponent_EmptyString() {
        XCTAssertEqual(AddressParser.extractStreetComponent(from: ""), "")
    }
    
    func testExtractStreetComponent_OnlyComma() {
        XCTAssertEqual(AddressParser.extractStreetComponent(from: ","), "")
    }
    
    func testExtractStreetComponent_ExtraSpaces() {
        let address = "  123 Main Street  ,  New York  ,  NY 10001  "
        XCTAssertEqual(AddressParser.extractStreetComponent(from: address), "123 Main Street")
    }
    
    func testExtractStreetComponent_SpecialCharactersInStreet() {
        let address = "123 O'Brien Street, Saint Mary's, MO 63673"
        XCTAssertEqual(AddressParser.extractStreetComponent(from: address), "123 O'Brien Street")
    }
    
    // MARK: - generateHouseName(from:) Tests
    
    func testGenerateHouseName_WithStreetName() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 Main Street"), "Main House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "456 Oak Avenue"), "Oak House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "789 Pine Road"), "Pine House")
    }
    
    func testGenerateHouseName_WithAbbreviatedSuffix() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 Elm St"), "Elm House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "456 Cedar Ave"), "Cedar House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "789 Maple Rd"), "Maple House")
    }
    
    func testGenerateHouseName_NoStreetSuffix() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 Broadway"), "Broadway House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "456 Fifth"), "Fifth House")
    }
    
    func testGenerateHouseName_SpecialCharacters() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 O'Brien Street"), "O'Brien House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "456 Saint Mary's Avenue"), "Saint Mary's House")
    }
    
    func testGenerateHouseName_EmptyString() {
        XCTAssertEqual(AddressParser.generateHouseName(from: ""), "My House")
    }
    
    func testGenerateHouseName_OnlyNumbers() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 456"), "My House")
    }
    
    func testGenerateHouseName_OnlyStreetSuffix() {
        XCTAssertEqual(AddressParser.generateHouseName(from: "Street"), "My House")
        XCTAssertEqual(AddressParser.generateHouseName(from: "123 Avenue"), "My House")
    }
    
    // MARK: - generateHouseNameFromAddress(_:) Tests
    
    func testGenerateHouseNameFromAddress_FullAddress() {
        let address = "123 Main Street, New York, NY 10001"
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(address), "Main House")
    }
    
    func testGenerateHouseNameFromAddress_InternationalAddress() {
        let address = "10 Downing Street, Westminster, London SW1A 2AA, United Kingdom"
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(address), "Downing House")
    }
    
    func testGenerateHouseNameFromAddress_NoComma() {
        let address = "456 Oak Avenue"
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(address), "Oak House")
    }
    
    func testGenerateHouseNameFromAddress_EmptyString() {
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(""), "My House")
    }
    
    func testGenerateHouseNameFromAddress_SpecialCharacters() {
        let address = "123 O'Brien Street, Saint Mary's, MO 63673"
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(address), "O'Brien House")
    }
    
    func testGenerateHouseNameFromAddress_ComplexStreetName() {
        let address = "123 Martin Luther King Jr. Boulevard, Atlanta, GA 30303"
        XCTAssertEqual(AddressParser.generateHouseNameFromAddress(address), "Martin Luther King Jr. House")
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testLongAddressComponents() {
        let longStreet = "123456789 Very Long Street Name That Goes On And On Avenue"
        let longCity = "Very Long City Name With Multiple Words"
        let address = "\(longStreet), \(longCity), CA 90001"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, longStreet)
        XCTAssertEqual(result?.city, longCity)
    }
    
    func testUnicodeCharacters() {
        let address = "123 Café Street, São Paulo, SP 01310-100, Brazil"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "123 Café Street")
        XCTAssertEqual(result?.city, "São Paulo")
        XCTAssertEqual(result?.state, "SP")
        XCTAssertEqual(result?.postalCode, "01310-100")
        XCTAssertEqual(result?.country, "Brazil")
    }
    
    func testAddressWithLineBreaks() {
        let address = "123 Main Street\n, New York\n, NY 10001"
        let result = AddressParser.parseComponents(from: address)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.street, "123 Main Street")
        XCTAssertEqual(result?.city, "New York")
    }
    
    func testAllStreetSuffixVariations() {
        // Test all suffix patterns mentioned in the regex
        let suffixes = [
            ("Street", "Main"),
            ("St", "Main"),
            ("Avenue", "Oak"),
            ("Ave", "Oak"),
            ("Road", "Pine"),
            ("Rd", "Pine"),
            ("Boulevard", "Elm"),
            ("Blvd", "Elm"),
            ("Lane", "Cedar"),
            ("Ln", "Cedar"),
            ("Drive", "Maple"),
            ("Dr", "Maple"),
            ("Court", "First"),
            ("Ct", "First"),
            ("Place", "Park"),
            ("Pl", "Park"),
            ("Way", "Kings"),
            ("Circle", "Round"),
            ("Cir", "Round"),
            ("Terrace", "Hill"),
            ("Ter", "Hill"),
            ("Parkway", "Green"),
            ("Pkwy", "Green")
        ]
        
        for (suffix, expectedName) in suffixes {
            let address = "123 \(expectedName) \(suffix)"
            XCTAssertEqual(AddressParser.extractStreetName(from: address), expectedName,
                          "Failed for suffix: \(suffix)")
        }
    }
}
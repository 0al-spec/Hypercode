import Testing
@testable import Hypercode

// MARK: - CascadeSheetReader: @contract: parsing

@Suite("Contract parsing") struct ContractParsingTests {
    let reader = CascadeSheetReader()

    @Test func parsesContractBlock() throws {
        let src = """
        @contract:
          service:
            timeout: int >= 1 <= 300
            name: string
        """
        let sheet = try reader.read(src)
        #expect(sheet.contracts.count == 1)
        let sc = sheet.contracts[0]
        #expect(sc.selector == .type("service"))
        #expect(sc.properties["timeout"]?.type == .int)
        #expect(sc.properties["timeout"]?.min == 1)
        #expect(sc.properties["timeout"]?.max == 300)
        #expect(sc.properties["timeout"]?.required == true)
        #expect(sc.properties["name"]?.type == .string)
        #expect(sc.properties["name"]?.required == true)
    }

    @Test func parsesOptionalConstraint() throws {
        let src = """
        @contract:
          service:
            timeout[?]: int >= 1
        """
        let sheet = try reader.read(src)
        let sc = sheet.contracts[0]
        #expect(sc.properties["timeout"]?.required == false)
        #expect(sc.properties["timeout"]?.min == 1)
        #expect(sc.properties["timeout"]?.max == nil)
    }

    @Test func parsesMultipleContractSelectors() throws {
        let src = """
        @contract:
          service:
            timeout: int
          .primary:
            replicas: int >= 2
        """
        let sheet = try reader.read(src)
        #expect(sheet.contracts.count == 2)
        #expect(sheet.contracts[0].selector == .type("service"))
        #expect(sheet.contracts[1].selector == .klass("primary"))
    }

    @Test func parsesContractAlongsideRules() throws {
        let src = """
        service:
          timeout: 30

        @contract:
          service:
            timeout: int >= 1
        """
        let sheet = try reader.read(src)
        #expect(sheet.rules.count == 1)
        #expect(sheet.contracts.count == 1)
    }

    @Test func rejectsUnknownConstraintType() {
        let src = """
        @contract:
          service:
            x: colour
        """
        #expect(throws: HCSError.self) { try reader.read(src) }
    }
}

// MARK: - ContractValidator: monotonicity

@Suite("ContractValidator") struct ContractValidatorTests {
    let validator = ContractValidator()

    private func contract(_ selector: Hypercode.Selector,
                          _ properties: [String: PropertyContract]) -> SelectorContract {
        SelectorContract(selector: selector, properties: properties, line: 1)
    }

    @Test func noViolation_identicalConstraints() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, required: true, min: 1, max: 300)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, required: true, min: 1, max: 300)])
        #expect(validator.validate([less, more]).isEmpty)
    }

    @Test func noViolation_moreSpecificNarrows() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, required: false, min: 1, max: 300)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, required: true, min: 10, max: 200)])
        #expect(validator.validate([less, more]).isEmpty)
    }

    @Test func typeMismatch_HC2101() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .float)])
        let diags = validator.validate([less, more])
        #expect(diags.count == 1)
        #expect(diags[0].code == "HC2101")
    }

    @Test func intervalWidening_lowerBound_HC2102() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, min: 5, max: nil)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, min: 1, max: nil)])
        let diags = validator.validate([less, more])
        #expect(diags.count == 1)
        #expect(diags[0].code == "HC2102")
        #expect(diags[0].message.contains("lower bound"))
    }

    @Test func intervalWidening_upperBound_HC2102() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 100)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, max: 200)])
        let diags = validator.validate([less, more])
        #expect(diags.count == 1)
        #expect(diags[0].code == "HC2102")
        #expect(diags[0].message.contains("upper bound"))
    }

    @Test func optionalWeakening_HC2103() {
        let less = contract(.type("service"), ["name": PropertyContract(type: .string, required: true)])
        let more = contract(.klass("primary"), ["name": PropertyContract(type: .string, required: false)])
        let diags = validator.validate([less, more])
        #expect(diags.count == 1)
        #expect(diags[0].code == "HC2103")
    }

    @Test func noViolation_unsharedKeys() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int)])
        let more = contract(.klass("primary"), ["replicas": PropertyContract(type: .int)])
        #expect(validator.validate([less, more]).isEmpty)
    }

    @Test func noViolation_sameSpecificity() {
        // Same specificity — neither is "more specific", so no check applies.
        let a = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 100)])
        let b = contract(.type("database"), ["timeout": PropertyContract(type: .int, max: 200)])
        #expect(validator.validate([a, b]).isEmpty)
    }
}

// MARK: - Validator integration

@Suite("Validator contract integration") struct ValidatorContractIntegrationTests {
    @Test func validatorRunsContractChecks() throws {
        let src = """
        @contract:
          service:
            timeout: int
          .primary:
            timeout: float
        """
        let sheet = try CascadeSheetReader().read(src)
        let diags = Validator().validate(sheet, against: [])
        let codes = diags.map(\.code)
        #expect(codes.contains("HC2101"))
    }
}

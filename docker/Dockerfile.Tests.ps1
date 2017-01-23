Describe "Verify Release Dockerfile ARGs" -tags "CI" {
    It "Should return data via Item()" {
	[string]$json.Item("Name") | Should Be "Zaphod Beeblebrox"
    }

    It "Should return data via []" {
	[string]$json["Planet"] | Should Be "Betelgeuse"
    }

    It "Should return nested data via Item().Item()" {
	[int]$json.Item("Appendages").Item("Heads") | Should Be 2
    }

    It "Should return nested data via [][]" {
	[int]$json["Appendages"]["Arms"] | Should Be 3
    }

    It "Should return correct array count" {
	$json["Achievements"].Count | Should Be 4
    }

    It "Should return array data via [n]" {
	[string]$json["Achievements"][3] | Should Be "One hoopy frood"
    }
}
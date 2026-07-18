import Testing

@testable import OpenOSKCore

@Suite struct ShellCompleterTests {
    private func makeCompleter() -> ShellCompleter {
        let completer = ShellCompleter()
        completer.load(data: ShellCompletionData(commands: [
            ShellCommandSpec(
                name: "git",
                flags: ["--version", "--help"],
                subcommands: [
                    ShellCommandSpec(name: "commit", flags: ["-m", "--amend", "--all"]),
                    ShellCommandSpec(name: "checkout", flags: ["-b"]),
                    ShellCommandSpec(name: "clone", flags: ["--depth"]),
                ]
            ),
            ShellCommandSpec(name: "grep", flags: ["-r", "-i"]),
        ]))
        return completer
    }

    @Test func completesCommandNames() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "g") == ["git", "grep"])
        #expect(completer.suggestions(forLine: "gi") == ["git"])
    }

    @Test func completesSubcommands() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "git c") == ["commit", "checkout", "clone"])
        #expect(completer.suggestions(forLine: "git ch") == ["checkout"])
    }

    @Test func completesFlags() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "git commit -") == ["-m", "--amend", "--all"])
        #expect(completer.suggestions(forLine: "git commit --a") == ["--amend", "--all"])
    }

    @Test func completesTopLevelFlags() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "git --v") == ["--version"])
    }

    @Test func ignoresSudoPrefix() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "sudo gi") == ["git"])
        #expect(completer.suggestions(forLine: "sudo git ch") == ["checkout"])
    }

    @Test func unknownCommandYieldsNothing() {
        let completer = makeCompleter()
        #expect(completer.suggestions(forLine: "foobar baz").isEmpty)
    }

    @Test func exactMatchIsNotSuggested() {
        let completer = makeCompleter()
        #expect(!completer.suggestions(forLine: "git").contains("git"))
    }

    @Test func bundledDataLoads() {
        let completer = ShellCompleter()
        completer.loadBundled()
        #expect(completer.suggestions(forLine: "gi").contains("git"))
        #expect(completer.suggestions(forLine: "git sta").contains("status"))
    }
}

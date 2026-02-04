**GOAL**

Learn more Odin and get better at programming again.

**Proposed Scope: "Good Enough for Real Tools" ****
We're building a library that can handle the CLI patterns you'd use in your own tools - not trying to compete with production-grade libraries, but something that id like to use for side projects and further expansion and learning. Baby steps into a shell and or text editor which are future goal projects as well.

Must Handle:

Flags (boolean switches)

--verbose or -v
Can be combined: -vvv for verbosity levels


Options (key-value pairs)

--output=file.txt or --output file.txt
-o file.txt


Positional arguments

The "rest" after flags: mytool --flag arg1 arg2 arg3


Basic validation

Required vs optional
Type checking (string, int, bool)
Error messages that don't suck


Help generation

--help prints usage automatically



Might Handle (stretch goals):

Subcommands (like git commit vs git push)
Environment variable fallbacks
Config file integration

Explicitly NOT Handling:

Complex option types (arrays, enums, custom parsing)
Bash completion generation
Man page generation
Windows-style / flags


Real-World Use Cases
Think about tools you'd actually build:
Example 1: Simple file processor
bashfiletool --verbose --format=json input.txt output.txt
Example 2: Your roguelike debug commands (maybe later)
bash# If you made a CLI launcher
roguelike --seed=12345 --debug --map-size=100x100
Example 3: A future shell command
bashmyshell --config=~/.myshellrc --no-history

The Real Goal
The meta-goal isn't just "make a parser" - it's to practice:

Designing before coding - What data structures represent this problem?
API thinking - What would make this pleasant to use?
Incremental building - Can we ship something minimal that works, then expand?
Odin idioms - How do Odin programmers solve these problems?

Locked-In Scope
Core features (we WILL finish these):

    - [ ] Flags (boolean switches with short/long forms)
    - [ ] Options (key-value with short/long forms)
    - [ ] Positional arguments
    - [ ] Basic validation and error messages
    - [ ] Auto-generated help text

Stretch goals (only if core is done and you're feeling it):

Subcommands
Fancier stuff


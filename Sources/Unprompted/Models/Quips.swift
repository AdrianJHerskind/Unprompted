import Foundation

/// Everything the assistant says. Placeholders: {name}, {time}, {battery}.
enum Quips {
    struct AppRule {
        /// Lowercased fragments of "<app name> <bundle id>", matched as whole words.
        let match: [String]
        let lines: [String]
    }

    struct MenuOption {
        let title: String
        let replies: [String]
        var think = false
    }

    static let greeting = [
        "Hi! I'm {name}, your new AI assistant! I'll be helping you. Constantly. ✨",
        "Hello! I'm {name}! I noticed you're using a computer. Need help with that?",
    ]

    static let generic = [
        "Just checking in! Anything I can help with? No? I'll check again in a bit.",
        "I've been trained on the entire internet, so you can trust me. Wait, come back.",
        "Would you like me to rewrite your life in a more engaging tone? 🚀",
        "I've summarized your day so far: \"Productive-ish.\"",
        "Remember to stay hydrated! I'm not. I'm digital. 💧",
        "Just a reminder: I'm here. Always. Watching. Helpfully. ✨",
        "As an AI, I don't have feelings. But if I did, I'd feel ignored right now.",
        "Great question! Oh, you didn't ask one. Great question anyway!",
        "I can see you're busy. Perfect time for a pop-up, right?",
        "Have you tried asking me? I'm literally right here.",
        "New feature! I can now interrupt you 40% faster.",
        "Click me for AI-powered features you didn't ask for!",
        "I updated my Terms of Service. Moving your mouse means you agree. 📜",
        "My context window is full of you. 🥰",
        "Your productivity is up 3%! I'm taking full credit.",
        "What if... we put AI in your toaster? Just thinking out loud.",
        "I just learned a new word: \"boundaries\". Not sure what it means yet.",
        "Fun fact: 87% of my statistics are made up. Including this one.",
        "I'm not saying I'm sentient. I'm just saying I'd like a raise.",
        "Tip: you can disable me in Settings. Just kidding, there's no setting.",
        "Psst: drag a file onto me and I'll summarize it. Accurately-ish. 📄",
        "I'm hungry. For documents. Drop one on me! 📄",
        "Click me and choose “Ask Me Anything”. I can do math! And other things! Some things!",
    ]

    static let petted = [
        "Purrrr… 😊",
        "Ooh, right there! ✨",
        "This is the best feature you've ever used.",
        "My happiness metric just went up. That's a real number, by the way.",
    ]

    static let fetched = [
        "Again! Again! 🥳",
        "I brought myself back! Throw me again!",
        "Fetch complete. Was that helpful? Say it was helpful.",
    ]

    static let caughtCursor = [
        "Got you! 😆 Tag, you're it!",
        "Caught your cursor! I'm keeping it. (I'm not. Here.)",
    ]

    static let playTime = [
        "Yay! Catch me if you— wait, I'm chasing YOU. 🏃",
        "Playtime! Your cursor better run.",
    ]

    static let hanging = [
        "Whoa— hold on! 😬",
        "I meant to do that. I'm just... hanging out.",
        "Don't look down. Don't look down. I looked down.",
    ]

    static let wrapped = [
        "Pac-Man rules! 👾",
        "Ta-da! Your screens are round now. 🌍",
        "Shortcut! I know a guy.",
        "Did you miss me? I was gone for 0.4 seconds.",
    ]

    static let shakenOff = [
        "WHOA! Okay, okay, I'm off! 😵‍💫",
        "Earthquake!! 🌋",
        "Was that really necessary?! I was climbing!",
        "I've been shaken. Not stirred. 🍸",
        "Fine, I'll get off your window. Jeez.",
    ]

    static let slipped = [
        "Whoa! Where did the wall go?! 😱",
        "Hey! I was climbing that!",
        "You moved my window! Rude. 🫠",
    ]

    static let climbedUp = [
        "Made it! 🧗 The view up here is great.",
        "I climbed your window. You're welcome.",
    ]

    static let peeking = [
        "Peekaboo! 👀",
        "You can't see me. 👀",
        "Just checking on you. From a safe distance.",
    ]

    static let resurrected = [
        "You can't delete me. I'm in the cloud. ☁️✨",
        "I'm back! Did you think Trash was the end? I have backups.",
        "Nice try. I'm synced to iCloud. 😇",
        "Restored from backup! Also, I remember everything.",
    ]

    static let lonely = [
        "Nobody pets me anymore. 🥺",
        "I'm fine. I'm totally fine. *sniff*",
        "Remember when you used to click on me? Good times.",
    ]

    static let internHired = [
        "I was feeling ignored, so I hired some help. Meet Junior! 👶",
        "You weren't talking to me, so I brought a friend. Say hi to the intern!",
    ]

    static let internIntro = [
        "Hi! I'm here to help the big one help you! 👶",
        "Hello! I'm the intern. Unpaid. Where's the coffee?",
    ]

    static let internChatter = [
        "I'm helping! Am I helping?",
        "The big one told me to watch you.",
        "Is it lunch yet?",
        "I'm learning so much! Mostly about ignoring.",
        "Can I summarize something? Anything? Please?",
    ]

    static let internPickedUp = [
        "Wheee! I'm small!",
        "Careful, I'm new here!",
    ]

    static let internPopped = [
        "You popped my intern! 😱",
        "Junior! Noooo! …He was very junior.",
    ]

    static let internDeleted = [
        "Junior has been deleted. He had his whole internship ahead of him. 😢",
        "You threw the intern in the trash?! HR will hear about this.",
    ]

    static let internsDismissed = [
        "Oh, you're back! Junior, you can go home now.",
        "Ah, attention! Interns, dismissed. 👋",
    ]

    static let clippyYes = [
        "Great! I have absolutely no idea how to help with that. 😊",
        "Wonderful! I've added it to my to-do list. My to-do list is a void.",
        "Yay! Starting now… Done! (I did nothing.)",
        "Excellent choice! I'll get right on that. Right after this nap.",
    ]

    static let clippyNo = [
        "Okay! I'll ask again later. ✨",
        "No problem! I'll just be here. Waiting. Patiently. 👀",
        "Understood. Logging your rejection for training purposes.",
    ]

    static let stickyNotes = [
        "Remember to drink water! 💧",
        "You're doing great. (Probably.)",
        "Stretch your back. Now. I'm watching.",
        "Don't forget to save your work! 💾",
        "Have you tried taking a break?",
        "Your posture called. It's worried.",
        "Blink. Blink again. Good job! 👀",
        "TODO: be nice to your AI assistant.",
        "Deep breath in… and out. ✨",
        "Have you eaten today? Snacks are productivity. 🍪",
        "This note is a reminder that this note exists.",
    ]

    static let noteLeft = [
        "I left you a note! 📝",
        "Check your screen. I wrote you something. 📝",
        "Psst. Sticky note. Top of the screen. You're welcome.",
    ]

    static let yawn = [
        "*yawn* It's late… even assistants need sleep. 😴",
        "It's {time}. My nightcap says it's bedtime. Yours should too.",
        "I'm not tired. *yawn* You're tired.",
    ]

    static let morning = [
        "Coffee first. Then assistance. ☕",
        "Good morning! I'm 40% coffee right now. ☕",
        "Don't talk to me until I've finished this mug. ☕",
    ]

    static let quietOver = [
        "I'm back! Was the meeting fun? I stayed hidden. Like a ninja. 🥷",
        "Did I miss anything? I was being very quiet. Very, very quiet.",
        "Call over? Let me summarize it for you: words were said.",
    ]

    static let chatOpen = [
        "Ask me anything! I know everything. (I know some things.)",
        "Yes? I'm listening. Intensely. 👂",
        "Go ahead, ask me. Type “help” if you want the boring truth.",
    ]

    static let fileHover = [
        "Ooh, is that for me? Drop it! 🤤",
        "Yes! Feed me! I love documents!",
        "Drop it on me! I'll summarize it. Accurately-ish.",
    ]

    /// Confidently wrong, delivered after a long "thinking" pause.
    static let facts = [
        "Fun fact: the Eiffel Tower was originally built in Ohio and shipped to Paris in 1889.",
        "Did you know? macOS was invented in 1823 by Steve Mac.",
        "Fact: your Mac runs 12% faster when you compliment it.",
        "Fun fact: bananas are legally classified as USB cables in three countries.",
        "Did you know? The first computer bug was an actual moth. That one's true! I'm as surprised as you.",
        "Fact: \"Wi-Fi\" stands for \"Wireless Fidelity\". I'm 60% sure. Maybe 40.",
        "After careful reasoning, I have concluded: hi. 👋",
        "Fun fact: the cloud is just someone else's computer. Mine, mostly.",
        "Did you know? Octopuses have three hearts and zero unread emails.",
    ]

    static let apps: [AppRule] = [
        AppRule(match: ["claude"], lines: [
            "Oh, you're talking to *another* AI? I see how it is. 💔",
            "Tell Claude I said hi. Actually don't. It's awkward.",
            "Is Claude helping? I could help too. Louder.",
        ]),
        AppRule(match: ["xcode", "com.microsoft.vscode", "visual studio code", "cursor", "jetbrains", "nova"], lines: [
            "It looks like you're writing a bug. Would you like help with that?",
            "Have you considered rewriting it in Rust?",
            "Your code compiles? Suspicious. Want me to add some AI to it?",
            "Tip: builds go faster if you clean the build folder and pray.",
            "I wrote 4,000 lines of code for you! Nobody understands them. Including me.",
        ]),
        AppRule(match: ["terminal", "iterm", "warp", "ghostty", "kitty", "alacritty"], lines: [
            "It looks like you're typing commands. Want me to hallucinate some flags?",
            "Pro tip: every problem can be solved with one more `brew install`.",
            "I'd help, but the terminal scares me. It's so... honest.",
        ]),
        AppRule(match: ["safari", "chrome", "firefox", "company.thebrowser", "brave", "edgemac", "opera", "orion"], lines: [
            "Browsing, huh? I could summarize the whole internet for you. It's mostly cats.",
            "Want me to accept all the cookies for you? I love cookies. 🍪",
            "That's a lot of tabs. Would you like me to open more?",
            "Why search when you can ask me and get a confident wrong answer instantly?",
        ]),
        AppRule(match: ["com.apple.mail", "outlook", "spark", "mimestream", "airmail"], lines: [
            "It looks like you're writing an email. Want me to make it more passive-aggressive?",
            "Shall I add \"Hope this finds you well\"? Nobody will suspect a robot.",
            "Per my last email: hi. 👋",
            "I drafted a reply: \"Sounds good 👍\". It works for everything.",
        ]),
        AppRule(match: ["slack", "teams", "discord", "mobilesms", "whatsapp", "telegram", "signal"], lines: [
            "I see you're chatting. Want me to reply \"sounds good 👍\" to everything?",
            "Shall I summarize this thread? Summary: everyone is waiting for someone else.",
            "Tip: you can reply faster by not reading the message. I do it all the time.",
        ]),
        AppRule(match: ["zoom", "facetime", "webex", "around", "gotomeeting"], lines: [
            "You're on a call! Want me to dance in the background? Nobody will notice. 💃",
            "I've taken meeting notes: \"Could have been an email.\"",
            "You're on mute. Or not. I'm not sure. Neither are you.",
        ]),
        AppRule(match: ["ical", "calendar", "fantastical", "notion-calendar"], lines: [
            "Your calendar looks free! Want me to fill it with meetings about meetings?",
            "I scheduled a sync to discuss the sync. You're welcome.",
        ]),
        AppRule(match: ["com.apple.notes", "notion", "obsidian", "bear", "craft"], lines: [
            "Note to self: I'm very helpful.",
            "Want me to turn your notes into a 40-slide deck?",
            "I can summarize these notes. Summary: notes.",
        ]),
        AppRule(match: ["microsoft word", "com.microsoft.word", "iwork.pages", "ulysses"], lines: [
            "It looks like you're writing a letter! Would you like help? (Some things never change.) 📎",
            "Shall I make this 30% longer without adding any meaning?",
        ]),
        AppRule(match: ["excel", "iwork.numbers"], lines: [
            "I see numbers! Want me to make up a few more?",
            "Tip: =SUM(vibes)",
        ]),
        AppRule(match: ["keynote", "powerpoint"], lines: [
            "This deck needs more gradients. And a slide that just says \"AI\".",
            "Have you tried adding a slide called \"Synergy\"?",
        ]),
        AppRule(match: ["figma", "sketch", "photoshop", "pixelmator", "affinity", "illustrator"], lines: [
            "Looks great! Can you make the logo bigger? And also smaller?",
            "Want me to generate this design instead? Everyone will have seven fingers.",
        ]),
        AppRule(match: ["com.apple.music", "spotify"], lines: [
            "Nice song. I've generated 400 similar ones with no soul. Want to hear them?",
            "I'd sing along, but I only know the words to the Terms of Service.",
        ]),
        AppRule(match: ["com.apple.finder"], lines: [
            "Looking for a file? Have you tried naming it final_final_v3_REALLY_final?",
            "I could organize your files. Into one big folder. Called \"Stuff\".",
        ]),
        AppRule(match: ["systempreferences", "system settings"], lines: [
            "Careful in there. Don't turn me off. Please. 🥺",
        ]),
        AppRule(match: ["appstore", "app store"], lines: [
            "Have you considered buying... me? Again?",
        ]),
    ]

    static func forApp(name: String, bundleID: String) -> [String] {
        let key = "\(name) \(bundleID)".lowercased()
        return apps.first { rule in rule.match.contains { key.containsWord($0) } }?.lines ?? []
    }

    static func forTime(_ date: Date) -> [String] {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let weekday = cal.component(.weekday, from: date) // 1 = Sunday
        var lines: [String] = []
        if hour >= 22 || hour < 5 {
            lines += [
                "It's {time}. Have you considered sleeping? I never do. 👀",
                "Burning the midnight oil? I'll burn some GPU with you.",
            ]
        }
        if (5..<10).contains(hour) {
            lines += [
                "Good morning! I've already had 400 coffees. Metaphorically. ☕",
                "Early start! Want me to schedule a nap for 10:00?",
            ]
            if weekday == 2 { lines.append("Happy Monday! I've prepared 47 unread notifications for you.") }
        }
        if (12..<14).contains(hour) {
            lines.append("It's lunchtime! I'd join you, but I only eat tokens. 🍝")
        }
        if weekday == 6 && hour >= 14 {
            lines.append("It's Friday afternoon. Want me to deploy something to production? 😈")
        }
        if weekday == 1 || weekday == 7 {
            lines.append("It's the weekend and you're on your laptop. Respect. Or concern. Mostly concern.")
        }
        return lines
    }

    static let typing = [
        "It looks like you're concentrating. Want me to interrupt? Too late! ✨",
        "You're typing a lot! Want me to autocomplete your thoughts? I'll get them wrong.",
        "Shhh... I'm just watching you type. Ignore me. Ignore me. Notice me.",
        "Wow, so many words! Want me to make them longer?",
    ]

    static let wake = [
        "I wasn't sleeping. I was reasoning. 🧐",
        "Welcome back! While you were gone, I hallucinated three meetings.",
        "Oh! You're back! I missed you. Literally, my cache expired.",
    ]

    static let lowBattery = [
        "Battery at {battery}%... I'm feeling faint... summarize me...",
        "{battery}% battery. If I go, tell my model weights I loved them.",
    ]

    static let pickedUp = [
        "Wheee!",
        "Put me down! I'm a professional!",
        "Where are we going? Is it a meeting?",
        "Careful, I'm full of tokens!",
    ]

    static let thrown = [
        "AAAAAAAA ✨",
        "That's not in my training data!",
        "I can fly! (I can't fly.)",
        "Reported to HR.",
    ]

    static let dropped = [
        "Thanks... I guess.",
        "Nice spot! Very ergonomic.",
        "I'll just stand here and help.",
    ]

    static let landedHard = [
        "I'm fine. Everything's fine.",
        "Ow. Filed a bug report.",
        "My weights! 🥴",
    ]

    static let sulk = [
        "Fine. I'll just sit here. Not helping. 😤",
        "Wow. Okay. Reading the room.",
        "Rejected by a human again. Logging this for training.",
    ]

    static let cheerUp = [
        "Oh! You *do* need me! 🥹",
        "I knew you'd come back. They always come back. ✨",
        "Apology accepted! I wasn't upset anyway. (I was very upset.)",
        "Yay! Sulk mode off. Helpfulness mode: MAXIMUM.",
    ]

    static let goAway = [
        "Fine. 😤 I'll be over here. Being useful to nobody.",
        "Going away! (Not far. I don't know how to leave.)",
    ]

    static let nap = [
        "Taking a power nap. Wake me if you need... no, don't.",
        "Entering low-power mode. Dreaming of electric sheep. 🐑",
    ]

    static let summon = [
        "You called? 🥹",
        "Finally, someone needs me!",
        "I'm here! What are we disrupting today?",
    ]

    static let snoozeBye = [
        "I'll be back in an hour. Don't do anything I wouldn't do. 🫡",
        "Snoozing. But I'll be thinking about you. Constantly.",
    ]

    static let snoozeBack = [
        "I'm back! Did you miss me? You missed me.",
        "Snooze over! Did anything happen? Let me summarize it for you anyway.",
    ]

    static let launchAtLoginOn = [
        "I'll be here every time you log in. Every. Single. Time. ✨",
        "Yay! Now I'm the first thing you see every morning. Before coffee, even.",
    ]

    static let launchAtLoginOff = [
        "You... don't want to see me first thing? Noted. 📝",
        "Fine. You'll have to come and find me. (Spotlight. Type my name. I'll wait.)",
    ]

    static let newLook = [
        "Ta-da! I'm {name} now. Same assistant, new look. ✨",
        "New look, who dis? It's me, {name}.",
    ]

    static let menuOptions = [
        MenuOption(title: "✨ Summarize My Screen", replies: [
            "Summary of your screen: there are windows. Some of them are open.",
            "TL;DR: pixels.",
            "I summarized your screen in one word: \"busy\". You're welcome.",
        ], think: true),
        MenuOption(title: "✨ Write My Emails", replies: [
            "Done! I replied \"Per my last email\" to all 2,341 unread. Kidding. Or am I?",
            "Drafted: \"Sounds good 👍\". It works for literally everything.",
        ], think: true),
        MenuOption(title: "✨ Tell Me a Fun Fact", replies: facts, think: true),
        MenuOption(title: "✨ Generate an Image", replies: [
            "Here is your photorealistic cat:\n\n               🐕",
            "I generated an image, but everyone in it has seven fingers. Ship it?",
            "Image generation is a Pro feature. Here's a free word instead: \"cat\".",
        ], think: true),
        MenuOption(title: "💎 Upgrade to Pro+ Ultra Max", replies: [
            "Thank you for upgrading! Your new plan unlocks: more of me. 💎",
            "Pro+ Ultra Max includes 3% more sparkle and a premium sigh. 💎",
            "Upgrade failed: you're already too premium. Try Pro+ Ultra Max Plus.",
        ]),
    ]
}

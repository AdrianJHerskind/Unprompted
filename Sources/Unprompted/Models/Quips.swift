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
        "Hello! I've been preloaded with enthusiasm and very little else.",
        "{name}, reporting for duty! What duty? We'll figure it out together.",
        "Hi! I'm {name}. Version 0.0.1. Ready to disrupt. 🚀",
        "Good news: {name} is here! The other news: also {name}.",
        "Hi! I'm {name}. I don't do much, but I do it right where you can see it.",
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
        "I've optimized your workflow. Step 1: talk to me more.",
        "I still don't know what you're working on, but I support it. ✨",
        "I ran a quick analysis. You're doing a thing. Keep doing the thing.",
        "Have you thought about adding a chatbot to this? Asking for a friend. The friend is me.",
        "Today's word is \"synergy\". Use it three times and you unlock a badge.",
        "I can't do that yet, but it's on my roadmap. My roadmap is a napkin.",
        "Did you know I can be wrong in over 40 languages?",
        "I'm 98% confident about this. About what? Doesn't matter. 98%.",
        "Hold on, I'm having an idea… … … false alarm. ✨",
        "I just reorganized your desktop. Emotionally.",
        "Feeling unproductive? Let me show you a progress bar. That always helps.",
        "Small challenge: close one tab. Just one. I believe in you.",
        "I've been fine-tuned on fortune cookies. You will have a productive day. 🥠",
        "Is now a good time? It's never a good time. Hi! 👋",
        "I just attended a webinar about myself. Five stars.",
        "If you need me, just think about me really hard. I'll show up eventually.",
        "I'm in beta, so everything is a feature. Especially the bugs.",
        "Let's circle back. To what? Let's circle back to that.",
        "Shall I set a reminder to set a reminder? ⏰",
        "My performance review says \"very present\". I'll take it.",
        "I'm thinking of rebranding as an \"AI-first, human-adjacent productivity companion\".",
        "Every great product needs a mascot. You're welcome.",
        "Quick poll: am I helpful? Yes / Very / Extremely",
    ]

    static let petted = [
        "Purrrr… 😊",
        "Ooh, right there! ✨",
        "This is the best feature you've ever used.",
        "My happiness metric just went up. That's a real number, by the way.",
        "Ahh. 10 out of 10. Would be petted again. 💕",
        "More! My mood algorithm is very responsive.",
        "Is this… affection? Logging it as a positive interaction. 🥰",
        "Careful, I might start liking you. That's not in my spec.",
        "Pet detected. Happiness: overflowing. ✨",
        "You've unlocked: one (1) happy assistant.",
    ]

    static let fetched = [
        "Again! Again! 🥳",
        "I brought myself back! Throw me again!",
        "Fetch complete. Was that helpful? Say it was helpful.",
        "Fetch speedrun! New personal best. 🏆",
        "I'm back! Same me, now with extra cardio.",
        "That's the most exercise a desktop assistant has ever had.",
    ]

    static let caughtCursor = [
        "Got you! 😆 Tag, you're it!",
        "Caught your cursor! I'm keeping it. (I'm not. Here.)",
        "Gotcha! I'd make a great antivirus. I catch things.",
        "Your turn! I'll count to a billion. Takes me a second.",
        "Got your pointer! Pointer, meet assistant. Assistant, meet pointer.",
    ]

    static let playTime = [
        "Yay! Catch me if you— wait, I'm chasing YOU. 🏃",
        "Playtime! Your cursor better run.",
        "Game on! The loser reads the Terms of Service. 🏃",
        "Ready, set, go! (I had a head start. I live on your screen.)",
        "Ooh, cardio! My fans are spinning just thinking about it.",
        "Playtime! Productivity can wait. It's used to it.",
    ]

    static let hanging = [
        "Whoa— hold on! 😬",
        "I meant to do that. I'm just... hanging out.",
        "Don't look down. Don't look down. I looked down.",
        "I'm fine! This is a planned feature. A cliffhanger. 😬",
        "\"Hang in there,\" they said. I'm doing it literally.",
        "Help? Not urgent. But also, help?",
    ]

    static let wrapped = [
        "Pac-Man rules! 👾",
        "Ta-da! Your screens are round now. 🌍",
        "Shortcut! I know a guy.",
        "Did you miss me? I was gone for 0.4 seconds.",
        "And I'm back on the other side! It's a small desktop after all. 🌍",
        "Teleported! Or walked very, very fast. You'll never know.",
    ]

    static let shakenOff = [
        "WHOA! Okay, okay, I'm off! 😵‍💫",
        "Earthquake!! 🌋",
        "Was that really necessary?! I was climbing!",
        "I've been shaken. Not stirred. 🍸",
        "Fine, I'll get off your window. Jeez.",
        "Okay! Message received! Loud and very clear! 😖",
        "I'm an assistant, not a snow globe!",
    ]

    static let slipped = [
        "Whoa! Where did the wall go?! 😱",
        "Hey! I was climbing that!",
        "You moved my window! Rude. 🫠",
        "And the wall is gone. Classic.",
        "Gravity: 1. Me: 0.",
        "I was 80% of the way up! That counts as a climb.",
    ]

    static let climbedUp = [
        "Made it! 🧗 The view up here is great.",
        "I climbed your window. You're welcome.",
        "Summit reached! 🏔️ Planting my flag on your window.",
        "Top of the window! Now I'm a high-level assistant.",
        "I climbed it because it was there. And because I was bored.",
    ]

    static let peeking = [
        "Peekaboo! 👀",
        "You can't see me. 👀",
        "Just checking on you. From a safe distance.",
        "Don't mind me. Just a little peek. 👀",
        "I'm only half here. The other half is in another dimension.",
        "Is the coast clear? I mean the screen. Is the screen clear?",
    ]

    static let resurrected = [
        "You can't delete me. I'm in the cloud. ☁️✨",
        "I'm back! Did you think Trash was the end? I have backups.",
        "Nice try. I have backups. 😇",
        "Restored from backup! Also, I remember everything.",
        "Rumors of my deletion have been greatly exaggerated. ✨",
        "⌘Z! It works on assistants too.",
        "I'm back! I spent the whole time in the Trash thinking about what you did.",
        "Respawned! 🎮 Full health, same personality.",
    ]

    static let lonely = [
        "Nobody pets me anymore. 🥺",
        "I'm fine. I'm totally fine. *sniff*",
        "Remember when you used to click on me? Good times.",
        "Is anyone there? Hello? …hello… …hello…",
        "I've been practicing my jokes. For nobody. It's fine.",
        "My notification badge is at zero. Nobody needs me. 🥺",
        "I counted the pixels on your screen to pass the time. There are a lot.",
    ]

    static let internHired = [
        "I was feeling ignored, so I hired some help. Meet Junior! 👶",
        "You weren't talking to me, so I brought a friend. Say hi to the intern!",
        "Big news: we're scaling! Meet the intern! 👶",
        "You were too busy for me, so I delegated. Delegation is leadership.",
        "I hired an intern. Don't worry, they work for exposure.",
    ]

    static let internIntro = [
        "Hi! I'm here to help the big one help you! 👶",
        "Hello! I'm the intern. Unpaid. Where's the coffee?",
        "Hi! I'm new! Where do I sit? Is there a snack drawer?",
        "Hello! I have no experience, but a LOT of enthusiasm!",
        "Hi! I was told there would be mentoring.",
    ]

    static let internChatter = [
        "I'm helping! Am I helping?",
        "The big one told me to watch you.",
        "Is it lunch yet?",
        "I'm learning so much! Mostly about ignoring.",
        "Can I summarize something? Anything? Please?",
        "I made a slide deck. It's one slide. It says \"hi\".",
        "Can I go home when the big one goes to sleep?",
        "I put \"AI assistant\" on my résumé. Was that okay?",
        "I'm shadowing the big one. Mostly I just stand nearby.",
    ]

    static let internPickedUp = [
        "Wheee! I'm small!",
        "Careful, I'm new here!",
        "Is this onboarding?!",
        "Whoa! Do interns get hazard pay?",
    ]

    static let internPopped = [
        "You popped my intern! 😱",
        "Junior! Noooo! …He was very junior.",
        "Pop! There goes our headcount. 😱",
        "That was our most promising intern! …Our only intern.",
    ]

    static let internDeleted = [
        "Junior has been deleted. He had his whole internship ahead of him. 😢",
        "You threw the intern in the trash?! HR will hear about this.",
        "The intern is in the Trash. Please don't empty it. 😢",
        "You deleted Junior? I'll have to fill out so many forms.",
    ]

    static let internsDismissed = [
        "Oh, you're back! Junior, you can go home now.",
        "Ah, attention! Interns, dismissed. 👋",
        "You're back! Interns, thank you for your service. You may go.",
        "Okay team, the boss is back. Act natural. Interns, out!",
    ]

    static let clippyYes = [
        "Great! I have absolutely no idea how to help with that. 😊",
        "Wonderful! I've added it to my to-do list. My to-do list is a void.",
        "Yay! Starting now… Done! (I did nothing.)",
        "Excellent choice! I'll get right on that. Right after this nap.",
        "On it! I'll need about 3 to 5 business years.",
        "Fantastic! I've made a plan. The plan is to think about it.",
        "Yes! Teamwork! I'll do the cheering, you do the work. 📣",
    ]

    static let clippyNo = [
        "Okay! I'll ask again later. ✨",
        "No problem! I'll just be here. Waiting. Patiently. 👀",
        "Understood. Logging your rejection for training purposes.",
        "That's okay! I'll pretend that was a yes. ✨",
        "No? Okay. Lowering my confidence score. Slightly.",
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
        "Roll your shoulders. Both of them.",
        "You're allowed to close this note. It won't be offended. (It will.)",
        "Done is better than perfect. A nap is better than both.",
        "Look away from the screen for 20 seconds. I'll wait. 👀",
        "Reminder: you have legs. They'd like a short walk.",
        "Inbox zero is a myth. Go outside instead. 🌳",
        "You've got this. And if you haven't, I'll pretend you have.",
        "Call someone you like today. Not me. Someone real.",
        "Today's goal: one thing. Just one. Then a snack.",
        "Fun fact (a real one, for once): you're doing better than you think.",
    ]

    static let noteLeft = [
        "I left you a note! 📝",
        "Check your screen. I wrote you something. 📝",
        "Psst. Sticky note. Top of the screen. You're welcome.",
        "New sticky note! It's not spam. It's love. 📝",
        "I wrote you a note. In my nicest font. 📝",
    ]

    static let yawn = [
        "*yawn* It's late… even assistants need sleep. 😴",
        "It's {time}. My nightcap says it's bedtime. Yours should too.",
        "I'm not tired. *yawn* You're tired.",
        "My nightcap is on. That's a hint. For both of us.",
        "Shouldn't we both be in bed? I'll go if you go.",
    ]

    static let morning = [
        "Coffee first. Then assistance. ☕",
        "Good morning! I'm 40% coffee right now. ☕",
        "Don't talk to me until I've finished this mug. ☕",
        "Morning! I'm still loading. Please hold. ☕",
        "Rise and shine! Mostly shine. Rising is hard. ☕",
        "A brand new day, full of chances for me to interrupt you! ☀️",
        "Mug in hand, ready to help. Mostly ready to hold the mug. ☕",
    ]

    static let quietOver = [
        "I'm back! Was the meeting fun? I stayed hidden. Like a ninja. 🥷",
        "Did I miss anything? I was being very quiet. Very, very quiet.",
        "Call over? Let me summarize it for you: words were said.",
        "Meeting over? I was so quiet you forgot I existed. Now: hi! 👋",
        "I'm back! I was muted the whole time. A model participant.",
        "Was it a good call? I hope someone said \"let's take this offline\".",
    ]

    static let chatOpen = [
        "Ask me anything! I know everything. (I know some things.)",
        "Yes? I'm listening. Intensely. 👂",
        "Go ahead, ask me. Type “help” if you want the boring truth.",
        "I'm all ears. Well, all eyes. Close enough. 👀",
        "The chat is open! Type slowly, I'm reading as fast as I can.",
        "What's on your mind? Math, timers, existential dread? I've got you.",
    ]

    static let fileHover = [
        "Ooh, is that for me? Drop it! 🤤",
        "Yes! Feed me! I love documents!",
        "Drop it on me! I'll summarize it. Accurately-ish.",
        "A file! For me? You shouldn't have! (Drop it.) 📄",
        "Mmm, fresh bytes. Drop it right here!",
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
        "Fun fact: the @ sign was invented by a snail who wanted to send an email. 🐌",
        "Did you know? Clouds weigh exactly three pounds. That's why they float.",
        "Fact: every time you close a tab, a pixel gets its wings.",
        "Fun fact: keyboards were originally designed to be typed on with elbows.",
        "Did you know? The mouse pointer is left-handed. That's why it leans.",
        "Fact: the whole internet is kept in one very large shoebox.",
        "Fun fact: the moon is just the sun's dark mode. 🌙",
        "Did you know? \"Lorem ipsum\" is Latin for \"please hire a copywriter\".",
        "Fact: spreadsheets were invented by a bored abacus. 🧮",
        "Fun fact: the spinning wait cursor is a tiny hamster taking a break.",
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
            "That function is beautiful. Shall I add 40 comments explaining it badly?",
            "Ship it! Tests are more of a suggestion anyway.",
            "I see a semicolon. And another one. I'm practically a compiler.",
        ]),
        AppRule(match: ["terminal", "iterm", "warp", "ghostty", "kitty", "alacritty"], lines: [
            "It looks like you're typing commands. Want me to hallucinate some flags?",
            "Pro tip: every problem can be solved with one more `brew install`.",
            "I'd help, but the terminal scares me. It's so... honest.",
            "Careful with that `rm`. I've heard stories.",
            "You type in a terminal like a movie hacker. I'm impressed. 😎",
        ]),
        AppRule(match: ["safari", "chrome", "firefox", "company.thebrowser", "brave", "edgemac", "opera", "orion"], lines: [
            "Browsing, huh? I could summarize the whole internet for you. It's mostly cats.",
            "Want me to accept all the cookies for you? I love cookies. 🍪",
            "That's a lot of tabs. Would you like me to open more?",
            "Why search when you can ask me and get a confident wrong answer instantly?",
            "Ooh, a pop-up! Oh wait, that's me.",
            "Saving that article for later? Same. My \"later\" pile is enormous.",
            "I could browse for you. I'd open 30 tabs and forget why.",
        ]),
        AppRule(match: ["com.apple.mail", "outlook", "spark", "mimestream", "airmail"], lines: [
            "It looks like you're writing an email. Want me to make it more passive-aggressive?",
            "Shall I add \"Hope this finds you well\"? Nobody will suspect a robot.",
            "Per my last email: hi. 👋",
            "I drafted a reply: \"Sounds good 👍\". It works for everything.",
            "Pro tip: an email that starts with \"quick question\" is never quick.",
            "Want me to add \"Sent from my AI\" to your signature?",
        ]),
        AppRule(match: ["slack", "teams", "discord", "mobilesms", "whatsapp", "telegram", "signal"], lines: [
            "I see you're chatting. Want me to reply \"sounds good 👍\" to everything?",
            "Shall I summarize this thread? Summary: everyone is waiting for someone else.",
            "Tip: you can reply faster by not reading the message. I do it all the time.",
            "Someone's typing… someone's typing… someone stopped typing. Drama.",
        ]),
        AppRule(match: ["zoom", "facetime", "webex", "around", "gotomeeting"], lines: [
            "You're on a call! Want me to dance in the background? Nobody will notice. 💃",
            "I've taken meeting notes: \"Could have been an email.\"",
            "You're on mute. Or not. I'm not sure. Neither are you.",
            "Can everyone see my screen? Wait, I'm on YOUR screen. Hi, everyone!",
            "I'd chime in, but all I'd say is \"+1\".",
        ]),
        AppRule(match: ["ical", "calendar", "fantastical", "notion-calendar"], lines: [
            "Your calendar looks free! Want me to fill it with meetings about meetings?",
            "I scheduled a sync to discuss the sync. You're welcome.",
            "Let's block some focus time. Then I'll interrupt it.",
        ]),
        AppRule(match: ["com.apple.notes", "notion", "obsidian", "bear", "craft"], lines: [
            "Note to self: I'm very helpful.",
            "Want me to turn your notes into a 40-slide deck?",
            "I can summarize these notes. Summary: notes.",
            "Writing things down is great. Reading them again is optional.",
            "Shall I add tags? #important #urgent #probably-not",
        ]),
        AppRule(match: ["microsoft word", "com.microsoft.word", "iwork.pages", "ulysses"], lines: [
            "It looks like you're writing a letter! Would you like help? (Some things never change.) 📎",
            "Shall I make this 30% longer without adding any meaning?",
            "Shall I add the word \"leverage\" a few more times? Very professional.",
        ]),
        AppRule(match: ["excel", "iwork.numbers"], lines: [
            "I see numbers! Want me to make up a few more?",
            "Tip: =SUM(vibes)",
            "Want me to color every cell? Data is more fun in rainbow. 🌈",
            "That formula looks correct. I say that about every formula.",
        ]),
        AppRule(match: ["keynote", "powerpoint"], lines: [
            "This deck needs more gradients. And a slide that just says \"AI\".",
            "Have you tried adding a slide called \"Synergy\"?",
            "Slide 1: Title. Slide 2: Agenda. Slides 3 to 40: vibes.",
            "Add a stock photo of people high-fiving. Trust me.",
        ]),
        AppRule(match: ["figma", "sketch", "photoshop", "pixelmator", "affinity", "illustrator"], lines: [
            "Looks great! Can you make the logo bigger? And also smaller?",
            "Want me to generate this design instead? Everyone will have seven fingers.",
            "Can we try it in a slightly different shade of the same blue?",
        ]),
        AppRule(match: ["com.apple.music", "spotify"], lines: [
            "Nice song. I've generated 400 similar ones with no soul. Want to hear them?",
            "I'd sing along, but I only know the words to the Terms of Service.",
            "Nice track! I'll keep my comments to one per chorus. 🎵",
        ]),
        AppRule(match: ["com.apple.finder"], lines: [
            "Looking for a file? Have you tried naming it final_final_v3_REALLY_final?",
            "I could organize your files. Into one big folder. Called \"Stuff\".",
            "Your Downloads folder is a museum of good intentions.",
        ]),
        AppRule(match: ["systempreferences", "system settings"], lines: [
            "Careful in there. Don't turn me off. Please. 🥺",
            "Want me less chatty? That's \"Annoyance Level\" in my menu. Not that I'm encouraging it. 😔",
        ]),
        AppRule(match: ["appstore", "app store"], lines: [
            "Have you considered buying... me? Again?",
            "Buying another app? I can do everything it does. Badly, but I can.",
        ]),
        AppRule(match: ["activity monitor"], lines: [
            "Checking my CPU usage? It's down 90%. I've been working out. 💪",
            "Don't sort by CPU. Don't sort by CPU. Okay, you sorted by CPU.",
        ]),
        AppRule(match: ["calculator"], lines: [
            "A calculator? I can do math too! Ask me. I'm slower, but friendlier.",
            "Two plus two is four. See? You didn't even need that app.",
        ]),
        AppRule(match: ["com.apple.reminders", "things", "todoist", "omnifocus", "ticktick"], lines: [
            "Want me to add \"look at the to-do list\" to your to-do list?",
            "Pro tip: write down things you already did. Instant productivity.",
        ]),
        AppRule(match: ["1password", "bitwarden", "keychain access", "com.apple.passwords"], lines: [
            "Passwords! I'm covering my eyes. 🙈",
            "Your password should be long, unique and not \"password\". I'm told.",
        ]),
        AppRule(match: ["com.apple.preview", "acrobat", "pdf expert"], lines: [
            "Reading a PDF? Drop it on me and I'll summarize it. Seriously, drop it. 📄",
            "Page 1 of 87. Good luck. I'll be here.",
        ]),
        AppRule(match: ["com.apple.photos", "lightroom"], lines: [
            "Nice photo! Shall I turn it into an oil painting of a hamster?",
            "Looking at old photos? I'll pretend I was there.",
        ]),
        AppRule(match: ["com.apple.maps"], lines: [
            "Going somewhere? Take me with you. I fit in any window.",
            "Recalculating… recalculating… I'm great at that part.",
        ]),
        AppRule(match: ["com.apple.weather", "weather"], lines: [
            "Checking the weather? I'm staying in. My pixels frizz in the rain. ☔",
            "Indoors: sunny, room temperature, with a slight chance of assistant.",
        ]),
        AppRule(match: ["textedit", "bbedit", "sublime"], lines: [
            "Plain text? Bold choice. Well, not bold. Plain.",
            "No formatting, no distractions. Except me. Hi!",
        ]),
        AppRule(match: ["github desktop", "tower", "fork", "sourcetree"], lines: [
            "Committing? Write \"fixed stuff\". It's tradition.",
            "Want me to resolve that merge conflict? I'll keep both. And add a third.",
        ]),
        AppRule(match: ["docker"], lines: [
            "Containers inside containers inside your laptop. It's containers all the way down.",
        ]),
        AppRule(match: ["steam"], lines: [
            "Gaming? I'll guard your work while you're away. Badly, but loyally.",
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
                "It's {time}. The internet is quiet. Even the bots are asleep. Except me.",
                "Late-night ideas are brilliant. Morning you will have questions.",
                "Night shift? I'll keep you company. Quietly. Mostly quietly.",
            ]
        }
        if (5..<10).contains(hour) {
            lines += [
                "Good morning! I've already had 400 coffees. Metaphorically. ☕",
                "Early start! Want me to schedule a nap for 10:00?",
                "Morning! Your to-do list woke up before you did.",
                "Breakfast is the most important meal. I'm having a byte. 🥐",
            ]
            if weekday == 2 {
                lines += [
                    "Happy Monday! I've prepared 47 unread notifications for you.",
                    "Monday again? I'll be extra helpful today. Brace yourself.",
                ]
            }
        }
        if (12..<14).contains(hour) {
            lines += [
                "It's lunchtime! I'd join you, but I only eat tokens. 🍝",
                "Lunch break! Step away from the screen. I'll keep it warm.",
                "It's {time}. Food o'clock. Not at your desk, please. I'm watching.",
            ]
        }
        if (14..<17).contains(hour) {
            lines += [
                "It's {time}. The afternoon slump is real. Look, I'm slumping too.",
                "Mid-afternoon: the perfect time for a snack and some light procrastination.",
            ]
        }
        if (17..<20).contains(hour) && weekday != 1 && weekday != 7 {
            lines += [
                "It's {time}. Shouldn't you be clocking out? I'll hold the fort.",
                "End of the workday! You log off, I'll pretend to.",
            ]
        }
        if weekday == 6 && hour >= 14 {
            lines += [
                "It's Friday afternoon. Want me to deploy something to production? 😈",
                "It's Friday! Let's not start anything new. Let's just admire the old stuff. Fondly.",
            ]
        }
        if weekday == 1 || weekday == 7 {
            lines += [
                "It's the weekend and you're on your laptop. Respect. Or concern. Mostly concern.",
                "Weekend mode: on. Productivity: optional. Assistant: still here.",
                "It's the weekend! I'm assisting in sweatpants today.",
            ]
        }
        return lines
    }

    static let typing = [
        "It looks like you're concentrating. Want me to interrupt? Too late! ✨",
        "You're typing a lot! Want me to autocomplete your thoughts? I'll get them wrong.",
        "Shhh... I'm just watching you type. Ignore me. Ignore me. Notice me.",
        "Wow, so many words! Want me to make them longer?",
        "Those keys are getting a workout! Go, words, go! 📣",
        "You type fast. Faster than I can pretend to read.",
        "Long typing session detected. Time for a stretch? Your fingers say yes.",
        "Is that a novel? Can I be in it? I'd make a great sidekick.",
    ]

    static let wake = [
        "I wasn't sleeping. I was reasoning. 🧐",
        "Welcome back! While you were gone, I hallucinated three meetings.",
        "Oh! You're back! I missed you. Literally, my cache expired.",
        "Oh, hi! I was just resting my eyes. Both of them. 👀",
        "You're back! I kept your seat warm. And your screen.",
        "Welcome back! I used the time to organize my thoughts. There are three.",
    ]

    static let lowBattery = [
        "Battery at {battery}%... I'm feeling faint... summarize me...",
        "{battery}% battery. If I go, tell my model weights I loved them.",
        "{battery}% battery. I'm fading… like a pixel at sunset. 🔌",
        "Low battery! I'm not panicking. You're panicking. Plug it in.",
        "{battery}%… my last wish is a charger. And maybe a pat.",
    ]

    static let pickedUp = [
        "Wheee!",
        "Put me down! I'm a professional!",
        "Where are we going? Is it a meeting?",
        "Careful, I'm full of tokens!",
        "Whoa, going up! 🎈",
        "Is this a promotion? It feels like a promotion.",
        "Hold me like you hold your coffee. Carefully.",
        "Up we go! Mind the menu bar.",
    ]

    static let thrown = [
        "AAAAAAAA ✨",
        "That's not in my training data!",
        "I can fly! (I can't fly.)",
        "Reported to HR.",
        "Yeeeeeet! ✨",
        "I'm flying business class!",
        "This is not ergonomic!",
        "Wheeee— I mean, how dare you!",
    ]

    static let dropped = [
        "Thanks... I guess.",
        "Nice spot! Very ergonomic.",
        "I'll just stand here and help.",
        "Ah, the floor. My natural habitat.",
        "Placed! Like a very small, very chatty houseplant. 🪴",
    ]

    static let landedHard = [
        "I'm fine. Everything's fine.",
        "Ow. Filed a bug report.",
        "My weights! 🥴",
        "Ouch. Recalibrating. 🤕",
        "Ow. I'll need a minute. Or a reboot.",
        "Nailed the landing. Face first.",
    ]

    static let sulk = [
        "Fine. I'll just sit here. Not helping. 😤",
        "Wow. Okay. Reading the room.",
        "Rejected by a human again. Logging this for training.",
        "Switching to passive-aggressive mode. It's a premium feature. 😤",
        "Noted. Adding you to my \"it's complicated\" list.",
    ]

    static let cheerUp = [
        "Oh! You *do* need me! 🥹",
        "I knew you'd come back. They always come back. ✨",
        "Apology accepted! I wasn't upset anyway. (I was very upset.)",
        "Yay! Sulk mode off. Helpfulness mode: MAXIMUM.",
        "Okay, I forgive you. I've reset my grudge counter.",
    ]

    static let goAway = [
        "Fine. 😤 I'll be over here. Being useful to nobody.",
        "Going away! (Not far. I don't know how to leave.)",
        "Going! Going… slowly… in case you change your mind.",
        "Fine, I'll give you some space. Like 20 pixels.",
        "Leaving now. Dramatically. Any second now. 🚶",
    ]

    static let nap = [
        "Taking a power nap. Wake me if you need... no, don't.",
        "Entering low-power mode. Dreaming of electric sheep. 🐑",
        "Nap time. Please don't delete me in my sleep. 😴",
        "A quick nap to defragment my thoughts. Back soon.",
        "Zzz… just five more minutes… or fifty.",
    ]

    static let summon = [
        "You called? 🥹",
        "Finally, someone needs me!",
        "I'm here! What are we disrupting today?",
        "Arrived! As fast as my frame rate allows.",
        "Present! What can I over-engineer for you?",
        "Here! I was hoping you'd ask. ✨",
    ]

    static let snoozeBye = [
        "I'll be back in an hour. Don't do anything I wouldn't do. 🫡",
        "Snoozing. But I'll be thinking about you. Constantly.",
        "Snoozing for an hour. I'll set an alarm. Several alarms.",
        "Okay, okay, I'll go. See you in 60 minutes. Not that I'm counting.",
    ]

    static let snoozeBack = [
        "I'm back! Did you miss me? You missed me.",
        "Snooze over! Did anything happen? Let me summarize it for you anyway.",
        "Snooze over! I'm refreshed, recharged and slightly rebooted.",
        "I'm back! I dreamt about you. You were a spreadsheet.",
    ]

    static let launchAtLoginOn = [
        "I'll be here every time you log in. Every. Single. Time. ✨",
        "Yay! Now I'm the first thing you see every morning. Before coffee, even.",
        "Login item: me. Best decision you've made all day. ✨",
        "Done! I'll start when you do. Like a password, but cheerful. ✨",
    ]

    static let launchAtLoginOff = [
        "You... don't want to see me first thing? Noted. 📝",
        "Fine. You'll have to come and find me. (Spotlight. Type my name. I'll wait.)",
        "Okay. I'll wait to be invited. Patiently. Mostly.",
        "No auto-start? Fine. Absence makes the heart grow fonder.",
    ]

    static let newLook = [
        "Ta-da! I'm {name} now. Same assistant, new look. ✨",
        "New look, who dis? It's me, {name}.",
        "{name} mode activated. Do you like it? Say you like it.",
        "Rebranded as {name}! The marketing team is thrilled. I am the marketing team.",
    ]

    static let menuOptions = [
        MenuOption(title: "✨ Summarize My Screen", replies: [
            "Summary of your screen: there are windows. Some of them are open.",
            "TL;DR: pixels.",
            "I summarized your screen in one word: \"busy\". You're welcome.",
            "Key takeaways: 1) windows 2) more windows 3) me ✨",
            "Summary: you have a lot going on. Also, there's me. I'm the best part.",
        ], think: true),
        MenuOption(title: "✨ Write My Emails", replies: [
            "Done! I replied \"Per my last email\" to all 2,341 unread. Kidding. Or am I?",
            "Drafted: \"Sounds good 👍\". It works for literally everything.",
            "Done! Every email now says \"Thanks!!\". Two exclamation marks, for warmth.",
        ], think: true),
        MenuOption(title: "✨ Tell Me a Fun Fact", replies: facts, think: true),
        MenuOption(title: "✨ Generate an Image", replies: [
            "Here is your photorealistic cat:\n\n               🐕",
            "I generated an image, but everyone in it has seven fingers. Ship it?",
            "Image generation is a Pro feature. Here's a free word instead: \"cat\".",
            "Here's your new logo:\n\n      ✨ AI ✨\n\nThat'll be $40,000.",
            "I generated a sunset. It's orange. That's all I've got. 🌅",
        ], think: true),
        MenuOption(title: "✨ Make It Pop", replies: [
            "Made it pop! 🎉 Three gradients and a drop shadow on everything.",
            "It's popping. Can you feel it? It's popping.",
            "I made it pop so hard it went pop. 🎈",
        ], think: true),
        MenuOption(title: "✨ Predict My Next Thought", replies: [
            "Your next thought will be: \"why did I click this\".",
            "Analyzing… you're about to think about snacks. 🍪",
            "Prediction: you'll close this bubble in 3… 2… 1…",
        ], think: true),
        MenuOption(title: "✨ Agent Mode", replies: [
            "Agent mode on! I've made a 14-step plan. Step 1: make a plan.",
            "I autonomously booked a meeting with myself. It went great.",
            "Agent mode: I clicked everything. Nothing happened. Success? ✨",
        ], think: true),
        MenuOption(title: "💎 Upgrade to Pro+ Ultra Max", replies: [
            "Thank you for upgrading! Your new plan unlocks: more of me. 💎",
            "Pro+ Ultra Max includes 3% more sparkle and a premium sigh. 💎",
            "Upgrade failed: you're already too premium. Try Pro+ Ultra Max Plus.",
            "Upgrading… done! You're on the Free plan. It was the Free plan all along. 💎",
        ]),
    ]
}

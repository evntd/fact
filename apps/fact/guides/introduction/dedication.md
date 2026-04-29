# Fact

*A File-System Based Event Sourcing Database Engine*

---

*For those who showed me the way*

---

In September 2024, at the Vancouver Event Modeling Unconference, I watched Adam Dymitruk demonstrate something that
seemed almost heretical in its simplicity: building an event sourcing database using a few lines of code and nothing but
the file system. No exotic dependencies. No architectural ceremony. Just the elegant application of first principles to
the problem at hand. Later, through his vibe-coded live streams of 2024 and 2025, I watched him continue to prove that
sometimes the best tools are the ones the operating system already gave us 40 years ago.

It was the kind of moment that makes you question everything you thought you knew; in the best possible way. Like
tasting wood-fired Neapolitan pizza for the first time when you'd only ever eaten frozen pizza. Or landing your first
kickflip
after months of eating pavement. The revelation isn't just in the trick itself; it's in realizing you had everything you
needed all along.

Fact is my response to that revelation. It's a file-system based event sourcing database engine that proves you don't
need to compromise on features to embrace simplicity. Like a good home-brewed beer, it takes time, attention to detail,
and a willingness to iterate until you get it right.

### What It Does

Fact handles the fundamentals you'd expect from any event sourcing database: append events to streams, read from the
global stream, replay specific streams. But it also embraces the Dynamic Consistency Boundary specification, allowing
writes directly to the ledger with append conditions to enforce write-side consistency and provide optimistic
concurrency controls. You can query events with precision, and carve the boundaries you need to accomplish the task
at hand.

The indexing system treats your events like a well-curated vinyl collection: organized by type, by tags, by streams, by
stream categories, by event data. Whatever makes sense for your access patterns, you can find it. And because staying in
sync is essential, Fact supports catch-up subscriptions to the global stream, specific streams, indexes, and event
queries. It's reactive when you need it to be, queryable when you don't.

### The Shoulders of Giants

This project stands on foundations built by people far smarter and more generous than I could hope to be.

---

#### To Greg Young

I found you on YouTube while searching for content regarding Event Tracing for Windows. A happy coincidence that our
technical vocabulary is wildly overloaded. I watched your Code On The Beach 2014 talk, and it caused a fundamental shift
in how I think about software. You handed me the mental models that changed everything. Event Sourcing. CQRS. The idea
that time is a dimension we can navigate, not just endure. The revelation that state is simply a consequence of events,
that we've been throwing away the most valuable data all along.

That talk started a decades-long journey of building and designing better systems. Every time I explain eventual
consistency to a skeptical developer, every time I model a domain as a series of facts instead of a mud-ball of
structural state, every time I choose immutability over mutation, I'm channeling something you taught me.

You gave me a new vocabulary for understanding systems, and with it, a new way of building them. Thank you for the
concepts that refuse to let go, and for making them accessible to someone who stumbled across them on the internet.

---

#### To Adam Dymitruk

Years into my journey, I struggled to convey the power of Event Sourcing and its ability to produce better designs to
the powers that be. It wasn't until I came across your Event Modeling blog post that it struck a chord. A step-by-step
guide to modeling event sourced systems written in the language of the business. I, like many others, had been mired in
the constant churn of requirements, going back to the well for additional funding, blowing up budgets and timelines.
These things are treated as normal, almost expected in software consulting. But you called it what it is: signs of poor
planning and questionable practices. Event Modeling solidified software development as a true engineering discipline
like any other traditional field of engineering, and gave me the tools and language to express Event Sourced systems in
terms businesses can relate to.

But beyond the code and the concepts, you've been a mentor in the truest sense. As I've started my own business, you've
been there. Sharing not just technical wisdom, but the hard-won lessons about what it takes to build something
sustainable. The conversations about business models, about finding clients, about staying true to your principles while
still paying the bills. You've shown me that you can be both technically excellent and commercially viable, that
simplicity isn't just a technical virtue but a business one.

Fact exists because you showed me it was possible. My business exists because you showed me it was doable.

---

#### To Martin Dilger

The time and energy you've poured into the Event Sourcing and Event Modeling communities is staggering. Your generosity
with sharing knowledge is beyond measure. I've consumed mountains of your content: talks, articles, workshops, insights.
Each piece has shaped how I think about these patterns and how to build a business around them.

You've made this space better just by being in it. You've made my journey better by making your knowledge so freely
available. Fact exists in part because you helped create an environment where these ideas could flourish. My business
exists in part because you helped create the confidence I needed to try.

---

#### To Sara Pellegrini, Bastian Waidelich, and Paul Grimshaw

The Dynamic Consistency Boundary pattern you developed is the kind of idea that makes you slap your forehead and say, "
Of course!" It solves the right problem in the right way, and Fact is better for having integrated it. You gave us a
spec that acknowledges the rigidity of DDD Aggregates, and provided guardrails enabling us to embrace the beautiful mess
and difficulty in boundary design. That's craft.

---

### What This Is Really About

At its core, Fact is about trust in simplicity and the conviction that the best solutions are often the ones you can
explain over a beer and a slice of pizza at 2am after a concert. It's about recognizing that complexity is often a
choice, and sometimes the best choice is to say no.

I built Fact because I wanted to see if event sourcing could be as simple as Adam made it look, but with all the
features I'd come to depend on in production systems. I wanted to prove to myself that you could have indexing,
subscriptions, static and dynamic consistency boundaries, and query flexibility without sacrificing the beautiful
directness of "it's just files."

Turns out, you can.

### A Final Note

Like skateboarding, brewing beer, or making a perfect pizza, building software is a practice. You're never done
learning. You're never done iterating. You're never done being humbled by how much you don't know.

Fact is my contribution to that practice. It's not perfect. It's not finished. But it's real, it works, and it stands on
the shoulders of people who cared enough to share what they learned.

So here's to the teachers, the builders, the craftspeople, and the pattern-makers. Here's to the decades-long journey of
getting better at this craft, one commit at a time.

And here's to you, reading this, hopefully building something of your own.

Let's make something simple together.

---

*Built with files, inspired by giants, debugged with coffee, while listening to Tool.*
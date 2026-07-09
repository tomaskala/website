---
title: "Simplifying"
date: 2026-05-27T18:27:34+02:00
draft: true
---

1. Ideas - what, why, how
2. Editors - obsidian & neovim
3. Languages - luckily no node, but since python is affected, i default to go for personal projects
4. GitHub - incidents, tried zizmor, more incidents, disabled
5. Later migration from github

Given the mess around GitHub outages/incidents, vibe-coded crap and supply-chain attacks, I started thinking about simplifying my computing environment. Anything that pulls in unvetted dependencies, plugins or runs arbitrary post-install hooks can become compromised. I went through the tools I use and got rid of most plugins that pull stuff from the outside. This means getting used to the defaults, using less fancy colorschemes and generally simplifying the tools I use, but it's been a pleasant experience overall.

I've only been using plugins in Obsidian.md and Neovim. I switched to the default Obsidian colorscheme and disabled all its community plugins. I'll really only miss the Markdown formatter, though formatting my randomly scattered notes is hardly a requirement. I haven't been able to remove all plugins from Neovim since I depend on telescope.nvim too much, but all the others turned out to be unnecessary. Unrelated, but I'm also experimenting with disabling most syntax highlighting. Neovim has this neat colorscheme called `quiet` that only highlights the comments and leaves all code elements uniformly colored. I was worried that it will be disorienting, but it's been going surprisingly well.

Thankfully I don't do any development in Node.js where most of the supply chain attacks occur. There have been some in the Python ecosystem though, so I've decided to default to Go for my own needs.

Due to all the security incidents, I removed all GitHub actions from my infrastructure repository. Earlier I experimented with [zizmor](https://zizmor.sh/) for actions hardening, but another GitHub incident proved them unreliable, so I ditched them altogether. I realize this is an overreaction since it's just a tiny personal repository with a server configuration, but it's also a way to reduce GitHub dependency, so that it's easier to migrate to another platform later.

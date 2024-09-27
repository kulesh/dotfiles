[user]
	name = Kulesh Shanmugasundaram
	email = kulesh@kulesh.org

[core]
	editor = vim
	whitespace = trailing-space,space-before-tab,cr-at-eol

[color]
	ui = true
	diff = true

[alias]
	last = cat-file commit HEAD
	st = status
	ci = commit
	co = checkout
  sme = shortlog -sn

[branch]
	autosetupmerge = true

[format]
	pretty = oneline

[credential]
        helper = osxkeychain
[init]
	templatedir = ~/.git_template

[filter "lfs"]
	clean = git-lfs clean -- %f
	smudge = git-lfs smudge -- %f
	process = git-lfs filter-process
	required = true

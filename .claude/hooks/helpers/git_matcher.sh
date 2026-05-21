# helpers/git_matcher.sh — shared regex fragment for `git <subcommand>` matchers.
# Source from any hook that needs to match git subcommands tolerantly.

# GIT_PREFIX is an ERE fragment that matches `git` followed by zero or more
# standard git-level options between `git` and the subcommand. Used as a
# prefix in every `git <subcommand>` matcher so the downstream gates fire
# even when the user supplies common option prefixes. See SPEC §6.1
# "Git option-prefix tolerance" for the contract.
#
# Tolerated options (single source of truth):
#   -c <key>=<value>             — per-invocation config
#   -C <path>                    — change directory
#   -p, --paginate               — page output
#   --no-pager                   — suppress pager
#   --git-dir=<path>             — custom .git
#   --work-tree=<path>           — custom work tree
#   --bare                       — bare repo flag
#   --namespace=<ref>            — ref namespace
#   --literal-pathspecs          — literal pathspec matching
#   --icase-pathspecs            — case-insensitive pathspec
#   --no-optional-locks          — skip refresh/index locks
#   --no-replace-objects         — disregard replace refs
#   --no-advice                  — suppress advice hints
#   --exec-path[=<path>]         — git exec path
#   --config-env=<name>=<envvar> — config from env
GIT_PREFIX='\bgit(\s+(-c\s+\S+|-C\s+\S+|-p|--paginate|--no-pager|--git-dir=\S+|--work-tree=\S+|--bare|--namespace=\S+|--literal-pathspecs|--icase-pathspecs|--no-optional-locks|--no-replace-objects|--no-advice|--exec-path(=\S+)?|--config-env=\S+))*\s+'

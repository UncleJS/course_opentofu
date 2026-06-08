# Module 08 — Functions & Expressions

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-08-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Intermediate-yellow)](.)
[![Time](https://img.shields.io/badge/Time-75%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [Expression Types](#expression-types)
- [String Functions](#string-functions)
- [Collection Functions](#collection-functions)
- [Numeric Functions](#numeric-functions)
- [Encoding Functions](#encoding-functions)
- [Filesystem Functions](#filesystem-functions)
- [Date and Time Functions](#date-and-time-functions)
- [Hash and Crypto Functions](#hash-and-crypto-functions)
- [IP Network Functions](#ip-network-functions)
- [Type Conversion Functions](#type-conversion-functions)
- [`templatefile()` Deep-Dive](#templatefile-deep-dive)
- [`dynamic` Blocks](#dynamic-blocks)
- [`try()` and `can()` for Defensive Expressions](#try-and-can-for-defensive-expressions)
- [`tofu console` as a Function Playground](#tofu-console-as-a-function-playground)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

HCL's built-in functions and expression syntax transform OpenTofu from a simple resource declaration language into a powerful configuration engine. This module is a comprehensive reference and guide to every major function category.

By the end of this module you will be able to:
- Use `for` expressions to transform and filter collections
- Apply the right function from each category for common tasks
- Generate complex config files with `templatefile()`
- Use `dynamic` blocks to avoid repetitive nested block declarations
- Write defensive expressions with `try()` and `can()`
- Use `tofu console` to test expressions interactively

↑ [Back to Table of Contents](#table-of-contents)

---

## Expression Types

### Literals and References

```hcl
# Literal values
"hello"
42
true
["a", "b", "c"]
{ key = "value" }

# References
var.name           # input variable
local.app_name     # local value
resource.type.name.attribute   # resource attribute
module.name.output # module output
path.module        # current module directory
terraform.workspace  # current workspace name
```

### Operators

```hcl
# Arithmetic
1 + 2       # 3
10 - 3      # 7
2 * 5       # 10
9 / 3       # 3
10 % 3      # 1

# Comparison
a == b      # equal
a != b      # not equal
a < b       # less than
a > b       # greater than
a <= b      # less than or equal
a >= b      # greater than or equal

# Logical
!true       # false
true && false  # false
true || false  # true
```

### Conditional Expression

```hcl
condition ? true_value : false_value

# Examples
var.environment == "prod" ? 5 : 1
length(var.names) > 0 ? var.names[0] : "default"
var.enable_tls ? "https" : "http"
```

### `for` Expression — List Form

```hcl
# Transform each element
[for s in var.names : upper(s)]
# ["ALICE", "BOB", "CAROL"]

# Filter elements
[for s in var.names : s if length(s) > 3]
# ["Alice", "Carol"] (if "Bob" is <= 3 chars)

# Index access
[for i, s in var.names : "${i}: ${s}"]
# ["0: Alice", "1: Bob", "2: Carol"]
```

### `for` Expression — Map Form

```hcl
# Transform a list into a map
{ for s in var.names : s => upper(s) }
# { "Alice" = "ALICE", "Bob" = "BOB" }

# Transform a map's values
{ for k, v in var.tags : k => trimspace(v) }

# Filter a map
{ for k, v in var.config : k => v if v != null }

# Invert a map (values become keys)
{ for k, v in var.name_to_id : v => k }
```

### Splat Expressions

```hcl
# Get all IDs from a count resource
local_file.files[*].filename
# equivalent to: [for f in local_file.files : f.filename]

# Nested splat
var.servers[*].interfaces[*].ip_address
```

↑ [Back to Table of Contents](#table-of-contents)

---

## String Functions

```hcl
# format — printf-style formatting
format("Hello, %s! You are %d years old.", "Alice", 30)
# "Hello, Alice! You are 30 years old."

# formatlist — format each element of a list
formatlist("server-%02d", [1, 2, 3])
# ["server-01", "server-02", "server-03"]

# join / split
join(", ", ["a", "b", "c"])       # "a, b, c"
split(",", "a,b,c")               # ["a", "b", "c"]
split(",", "  a , b , c  ")       # ["  a ", " b ", " c  "] — note no trimming

# replace
replace("hello world", "world", "OpenTofu")   # "hello OpenTofu"
replace("hello-world", "-", "_")              # "hello_world"

# regex / regexall
regex("^(\\w+)-(.+)$", "hello-world")         # ["hello-world", "hello", "world"]
regexall("\\d+", "abc123def456")              # ["123", "456"]
can(regex("^\\d+$", var.input))               # true if var.input is all digits

# Case
upper("hello")    # "HELLO"
lower("HELLO")    # "hello"
title("hello world")  # "Hello World"

# Trimming
trimspace("  hello  ")     # "hello"
trimprefix("!hello", "!")  # "hello"   — removes the prefix (from the start)
trimsuffix("hello!", "!")  # "hello"   — removes the suffix (from the end)
trim("__hello__", "_")     # "hello"   — trims the given chars from both ends

# Other
chomp("hello\n")           # "hello" — removes trailing newline
indent(4, "line1\nline2")  # "    line1\n    line2"
substr("hello world", 0, 5) # "hello"

startswith("hello", "he")  # true
endswith("hello", "lo")    # true

# templatestring (inline templates — 1.8+)
templatestring("Hello, $${name}!", { name = "Alice" })
# "Hello, Alice!"
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Collection Functions

```hcl
# Length
length(["a", "b", "c"])    # 3
length({ a = 1, b = 2 })   # 2
length("hello")            # 5

# Keys / Values
keys({ b = 2, a = 1 })     # ["a", "b"] — sorted alphabetically
values({ b = 2, a = 1 })   # [1, 2]     — values in key-sorted order

# Lookup (map access with default)
lookup({ env = "prod" }, "env", "dev")     # "prod"
lookup({ env = "prod" }, "region", "us")   # "us" (default)

# contains
contains(["a", "b", "c"], "b")   # true
contains(["a", "b", "c"], "z")   # false

# element — access list by (wrapped) index
element(["a", "b", "c"], 0)   # "a"
element(["a", "b", "c"], 5)   # "c" (5 % 3 = 2, then index 2)

# flatten — recursively flatten nested lists
flatten([["a", "b"], ["c", ["d", "e"]]])
# ["a", "b", "c", "d", "e"]

# concat — join lists
concat(["a", "b"], ["c", "d"])   # ["a", "b", "c", "d"]

# merge — merge maps (later maps override earlier)
merge({ a = 1 }, { b = 2 }, { a = 99 })
# { a = 99, b = 2 }

# Set operations
setintersection(["a", "b", "c"], ["b", "c", "d"])   # ["b", "c"]
setsubtract(["a", "b", "c"], ["b"])                  # ["a", "c"]
setunion(["a", "b"], ["b", "c"])                     # ["a", "b", "c"]

# distinct — remove duplicates
distinct(["a", "b", "a", "c"])   # ["a", "b", "c"]

# compact — remove null and empty strings
compact(["a", "", null, "b"])    # ["a", "b"]

# zipmap — create map from two lists
zipmap(["a", "b", "c"], [1, 2, 3])   # { a = 1, b = 2, c = 3 }

# transpose — invert a map of lists
transpose({ a = ["x", "y"], b = ["x"] })
# { x = ["a", "b"], y = ["a"] }

# chunklist — split list into chunks
chunklist(["a", "b", "c", "d", "e"], 2)   # [["a", "b"], ["c", "d"], ["e"]]

# slice — sublist
slice(["a", "b", "c", "d"], 1, 3)   # ["b", "c"]

# reverse
reverse(["a", "b", "c"])   # ["c", "b", "a"]

# sort
sort(["c", "a", "b"])      # ["a", "b", "c"]

# tolist / toset / tomap — type conversions
tolist(toset(["c", "a", "b"]))   # ["a", "b", "c"] — sorted
toset(["a", "b", "a"])           # {"a", "b"} — deduplicated
tomap({ a = "1", b = "2" })      # { a = "1", b = "2" }

# alltrue / anytrue (1.6+)
alltrue([true, true, false])   # false
anytrue([false, true, false])  # true

# one — extract single element from a set/list (error if not exactly 1)
one(["value"])   # "value"
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Numeric Functions

```hcl
abs(-5)         # 5
ceil(1.2)       # 2
floor(1.9)      # 1
max(3, 1, 4)    # 4
min(3, 1, 4)    # 1
pow(2, 10)      # 1024
signum(-5)      # -1 (sign: -1, 0, or 1)
log(8, 2)       # 3.0 (log base 2 of 8)
parseint("ff", 16)  # 255 (parse "ff" in base 16)
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Encoding Functions

```hcl
# Base64
base64encode("Hello, OpenTofu!")   # "SGVsbG8sIE9wZW5Ub2Z1IQ=="
base64decode("SGVsbG8sIE9wZW5Ub2Z1IQ==")   # "Hello, OpenTofu!"

# JSON
jsonencode({ name = "Alice", age = 30 })
# "{\"age\":30,\"name\":\"Alice\"}"

jsondecode("{\"name\":\"Alice\",\"age\":30}")
# { name = "Alice", age = 30 }

# YAML
yamlencode({ name = "Alice", tags = ["admin", "dev"] })
# "name: Alice\ntags:\n  - admin\n  - dev\n"

yamldecode("name: Alice\nage: 30\n")
# { name = "Alice", age = 30 }

# URL encoding
urlencode("hello world & more")   # "hello+world+%26+more"

# CSV
csvdecode("a,b,c\n1,2,3\n4,5,6\n")
# [{ a="1", b="2", c="3" }, { a="4", b="5", c="6" }]
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Filesystem Functions

```hcl
# Read a file as a string
file("${path.module}/config/app.conf")

# Read a file as base64
filebase64("${path.module}/assets/logo.png")

# Check if a file exists
fileexists("${path.module}/optional.conf")   # true or false

# List files matching a pattern
fileset("${path.module}/configs", "*.json")
# ["app.json", "db.json", "cache.json"]

# Render a template file
templatefile("${path.module}/templates/config.tpl", {
  server_name = var.server_name
  port        = var.port
})

# Path helpers
dirname("/path/to/file.txt")    # "/path/to"
basename("/path/to/file.txt")   # "file.txt"
pathexpand("~/configs")         # "/home/user/configs"
abspath("relative/path")        # "/absolute/path"
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Date and Time Functions

```hcl
# Current timestamp (RFC 3339 format)
timestamp()   # "2026-03-02T10:00:00Z"

# Add duration to a timestamp
timeadd("2026-03-02T10:00:00Z", "24h")    # "2026-03-03T10:00:00Z"
timeadd("2026-03-02T10:00:00Z", "-1h30m") # "2026-03-02T08:30:00Z"

# Format a timestamp
formatdate("YYYY-MM-DD", "2026-03-02T10:00:00Z")       # "2026-03-02"
formatdate("DD MMM YYYY hh:mm:ss", "2026-03-02T10:00:00Z")  # "02 Mar 2026 10:00:00"

# Compare timestamps (-1, 0, or 1)
timecmp("2026-03-01T00:00:00Z", "2026-03-02T00:00:00Z")   # -1 (first is earlier)
```

> **Warning:** `timestamp()` is evaluated at apply time and produces a different value on each apply. Using it in a resource argument will cause drift on every plan. Use it only in locals for one-time values, or use `null_resource` triggers.

↑ [Back to Table of Contents](#table-of-contents)

---

## Hash and Crypto Functions

```hcl
# File hashes (useful for triggers)
filemd5("${path.module}/script.sh")     # MD5 hash of file contents
filesha256("${path.module}/config.txt") # SHA-256 hash of file

# String hashes
md5("hello world")       # "5eb63bbbe01eeed093cb22bb8f5acdc3"
sha1("hello world")      # "2aae6c69..."
sha256("hello world")    # "b94d27b9..."
sha512("hello world")    # "309ecc48..."

# bcrypt (for password hashing)
bcrypt("my-password", 10)   # "$2a$10$..."

# UUID
uuid()      # "6f7b7e4c-..." — random UUID v4 (changes on each call)
uuidv5("dns", "example.com")   # deterministic UUID v5
```

↑ [Back to Table of Contents](#table-of-contents)

---

## IP Network Functions

```hcl
# CIDR subnet calculations
cidrsubnet("10.0.0.0/16", 8, 0)   # "10.0.0.0/24"
cidrsubnet("10.0.0.0/16", 8, 1)   # "10.0.1.0/24"
cidrsubnet("10.0.0.0/16", 8, 255) # "10.0.255.0/24"

# Generate multiple subnets
cidrsubnets("10.0.0.0/16", 8, 8, 8)
# ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

# Host address in a subnet
cidrhost("10.0.0.0/24", 1)     # "10.0.0.1"
cidrhost("10.0.0.0/24", 254)   # "10.0.0.254"

# Subnet mask
cidrnetmask("10.0.0.0/24")     # "255.255.255.0"
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Type Conversion Functions

```hcl
tostring(42)       # "42"
tonumber("42")     # 42
tobool("true")     # true

# try — evaluate first successful expression
try(var.optional_map["key"], "default")
try(local.maybe_null.attribute, "fallback")

# can — test if expression would succeed
can(var.optional_map["key"])   # true if key exists
can(regex("^\\d+$", var.input)) # true if input matches

# issensitive / nonsensitive
issensitive(var.password)         # true
nonsensitive(var.password)        # strips sensitive marking (use carefully!)
```

↑ [Back to Table of Contents](#table-of-contents)

---

## `templatefile()` Deep-Dive

`templatefile()` reads a file and renders it as a template. The template syntax is HCL expression syntax.

### Template Syntax

```
# templates/nginx.conf.tpl

server {
  server_name ${server_name};
  listen ${port};

  # Conditional
  %{ if tls_enabled ~}
  ssl_certificate     ${tls_cert};
  ssl_certificate_key ${tls_key};
  %{ endif ~}

  # Loop
  %{ for location in locations ~}
  location ${location.path} {
    proxy_pass ${location.backend};
  }
  %{ endfor ~}
}
```

```hcl
resource "local_file" "nginx_config" {
  filename = "output/nginx.conf"
  content  = templatefile("${path.module}/templates/nginx.conf.tpl", {
    server_name  = var.server_name
    port         = var.port
    tls_enabled  = var.enable_tls
    tls_cert     = var.tls_cert_path
    tls_key      = var.tls_key_path
    locations    = var.proxy_locations
  })
}
```

### Whitespace Control with `~`

The `~` after `%{` or before `%}` trims whitespace (including newlines) from the adjacent text:

```
%{ for item in items ~}
- ${item}
%{ endfor ~}
```

Without `~`: extra blank lines appear. With `~`: clean compact output.

### Passing Complex Objects

```hcl
# templates/inventory.tpl
[servers]
%{ for name, server in servers ~}
${name} ansible_host=${server.ip} ansible_port=${server.port}
%{ endfor ~}

# main.tf
resource "local_file" "ansible_inventory" {
  filename = "output/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    servers = {
      web01 = { ip = "10.0.0.1", port = 22 }
      web02 = { ip = "10.0.0.2", port = 22 }
      db01  = { ip = "10.0.1.1", port = 2222 }
    }
  })
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## `dynamic` Blocks

`dynamic` blocks allow you to generate repeated nested blocks from a collection.

### Basic Syntax

```hcl
resource "example_server" "web" {
  name = "web"

  dynamic "ingress_rule" {
    for_each = var.ingress_rules
    content {
      port     = ingress_rule.value.port
      protocol = ingress_rule.value.protocol
      cidr     = ingress_rule.value.cidr
    }
  }
}
```

The `iterator` argument customises the block's iteration variable name (defaults to the block type):

```hcl
dynamic "ingress_rule" {
  for_each = var.ingress_rules
  iterator = rule  # use "rule" instead of "ingress_rule"
  content {
    port     = rule.value.port
    protocol = rule.value.protocol
  }
}
```

### Nested `dynamic` Blocks

```hcl
dynamic "environment" {
  for_each = var.environments
  content {
    name = environment.key

    dynamic "variable" {
      for_each = environment.value.vars
      content {
        name  = variable.key
        value = variable.value
      }
    }
  }
}
```

### When NOT to Use `dynamic`

`dynamic` blocks can make configurations hard to read. Prefer them only when:
- The number of nested blocks is genuinely variable (driven by input data)
- A static list of blocks would require significant repetition

Avoid using `dynamic` just to look clever — static blocks are easier to read and reason about.

↑ [Back to Table of Contents](#table-of-contents)

---

## `try()` and `can()` for Defensive Expressions

### `try()` — First Successful Expression

```hcl
# Safe map key access with default
local.config["optional_key"]        # ERROR if key doesn't exist
try(local.config["optional_key"], "default_value")  # safe

# Safe nested attribute access
try(var.server.tls.cert_path, "")  # returns "" if tls is null

# Multiple fallbacks
try(
  var.config.advanced.timeout,
  var.config.timeout,
  30   # final default
)
```

### `can()` — Test Expression Validity

```hcl
# Test if a map key exists
can(var.overrides["specific_key"])   # true or false

# Test regex match
can(regex("^[a-z]+$", var.name))     # true if name is all lowercase

# Use in validation
validation {
  condition     = can(regex("^[a-z][a-z0-9-]*$", var.resource_name))
  error_message = "Resource name must start with a lowercase letter."
}
```

### Combining `try()` and `can()` for Optional Attributes

```hcl
locals {
  # Use the custom timeout if provided and valid, otherwise use default
  timeout = can(tonumber(var.custom_timeout)) && tonumber(var.custom_timeout) > 0
    ? tonumber(var.custom_timeout)
    : 30
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## `tofu console` as a Function Playground

The `tofu console` command opens an interactive REPL where you can evaluate HCL expressions against the current configuration and state.

```bash
cd modules/03-providers-and-resources/examples
tofu init
tofu apply -auto-approve

# Open the REPL
tofu console
```

Inside the console:

```hcl
# Test functions
> upper("hello world")
"HELLO WORLD"

> join(", ", ["a", "b", "c"])
"a, b, c"

> [for s in ["alice", "bob", "carol"] : upper(s) if length(s) > 3]
["ALICE", "CAROL"]

# Inspect state values
> local_file.env_config["dev"].filename
"output/dev-config.txt"

> keys(local_file.env_config)
["dev", "prod", "staging"]

# Test complex expressions before adding to config
> { for k, v in { a = 1, b = 2, c = 3 } : k => v * 2 if v > 1 }
{ b = 4, c = 6 }

# Exit with Ctrl+C or Ctrl+D
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Console Exploration

Open `tofu console` in the Module 03 examples directory (after applying) and:

1. Use `keys()`, `values()`, `length()` on the `local_file.env_config` resource map
2. Test 5 string functions: `upper()`, `replace()`, `split()`, `join()`, `format()`
3. Test a `for` expression that filters the env map to only envs with names longer than 3 chars
4. Use `jsonencode()` on a complex object and verify the output
5. Test `try()` with a missing map key — confirm it returns the fallback

Write down your 5 most surprising or useful discoveries.

---

### Exercise 2 — Medium: templatefile() Config Generator

Build a configuration that:

1. Accepts a `map(object({...}))` variable `services` where each service has: `name`, `port`, `protocol`, `environment`, `tags (map(string))`
2. Uses `templatefile()` to generate:
   - An `inventory.ini` in Ansible inventory format
   - A `docker-compose.yml` in YAML format using `yamlencode()`
   - A `summary.txt` human-readable report
3. Uses `for` expressions and `join()` inside the templates
4. Outputs the path to each generated file

---

### Exercise 3 — Hard: Complex Transformation Pipeline

Build a configuration that:

1. Accepts a deeply nested input variable `app_topology`:
   ```hcl
   map(object({
     services = map(object({
       port     = number
       replicas = optional(number, 1)
       env_vars = optional(map(string), {})
     }))
     networks = optional(list(string), [])
   }))
   ```
2. Uses `for` expressions, `flatten()`, `zipmap()`, and `merge()` to transform this into:
   - A flat list of all service instances (app + service + replica index)
   - A map of `"app/service"` → list of port numbers
   - A deduplicated set of all network names across all apps
3. Uses `dynamic` blocks to generate a multi-block resource from the flat service list
4. Adds `try()`/`can()` guards for all optional attributes
5. Creates a `local_file` for each derived structure (as JSON) and a summary report

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Built-in Functions](https://opentofu.org/docs/language/functions/) — Complete function reference
- [For Expressions](https://opentofu.org/docs/language/expressions/for/) — Full for expression syntax
- [Dynamic Blocks](https://opentofu.org/docs/language/expressions/dynamic-blocks/) — Dynamic block reference
- [String Templates](https://opentofu.org/docs/language/expressions/strings/) — Template directives reference
- [Type Constraints](https://opentofu.org/docs/language/expressions/type-constraints/) — Type system reference
- [tofu console Command](https://opentofu.org/docs/cli/commands/console/) — Console REPL reference

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| `for` expressions | Transform/filter lists and maps; list form `[...]`, map form `{...}` |
| String functions | `format()`, `join()`, `split()`, `replace()`, `regex()`, `trimspace()` |
| Collection functions | `flatten()`, `merge()`, `zipmap()`, `distinct()`, `compact()`, `keys()` |
| `templatefile()` | Generate files from HCL templates; use `~` for whitespace control |
| `dynamic` blocks | Variable nested block count; use sparingly for readability |
| `try()` | Return first non-error expression; safe optional access |
| `can()` | Test if expression succeeds; use in validations |
| `tofu console` | Interactive REPL; test expressions before committing to config |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 09 — Backends & Remote State](../09-backends-and-remote-state/09-backends-and-remote-state.md)**

Configure remote backends, implement state encryption at rest, share state across configurations, and master backend migrations.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>
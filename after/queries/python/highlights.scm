; Custom Hacker theme overrides for python

; Builtin functions in call sites (len, print, sorted, etc)
((call
  function: (identifier) @function.builtin)
  (#any-of? @function.builtin
    "abs" "aiter" "all" "anext" "any" "ascii" "bin" "bool" "breakpoint"
    "bytearray" "bytes" "callable" "chr" "classmethod" "compile" "complex"
    "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec" "filter"
    "float" "format" "frozenset" "getattr" "globals" "hasattr" "hash"
    "help" "hex" "id" "input" "int" "isinstance" "issubclass" "iter" "len"
    "list" "locals" "map" "max" "memoryview" "min" "next" "object" "oct"
    "open" "ord" "pow" "print" "property" "range" "repr" "reversed" "round"
    "set" "setattr" "slice" "sorted" "staticmethod" "str" "sum" "super"
    "tuple" "type" "vars" "zip" "__build_class__" "__import__")
  (#set! priority 120))

; Dunder methods (e.g. __init__) in class definitions and attribute usage
((class_definition
  body: (block
    (function_definition
      name: (identifier) @method.builtin)))
  (#lua-match? @method.builtin "^__.*__$")
  (#set! priority 110))

((attribute
  attribute: (identifier) @method.builtin)
  (#lua-match? @method.builtin "^__.*__$")
  (#set! priority 110))

; Named parameters in call sites
((call
  arguments: (argument_list
    (keyword_argument
      name: (identifier) @parameter.name)))
  (#set! priority 110))

((call
  arguments: (argument_list
    (default_parameter
      name: (identifier) @parameter.name)))
  (#set! priority 110))

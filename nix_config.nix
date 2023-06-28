with builtins; let
  boolToString = b:
    if b
    then "true"
    else "false";

  /*
  Check whether a value can be coerced to a string.
  The value must be a string, path, or attribute set.

  String-like values can be used without explicit conversion in
  string interpolations and in most functions that expect a string.
  */
  isStringLike = x:
    isString x
    || isPath x
    || x ? outPath
    || x ? __toString;

  mapAttrsToList =
    # A function, given an attribute's name and value, returns a new value.
    f:
    # Attribute set to map over.
    attrs:
      map (name: f name attrs.${name}) (attrNames attrs);

  mkValueString = v:
    if v == null
    then ""
    else if isInt v
    then toString v
    else if isBool v
    then boolToString v
    else if isFloat v
    then toString v
    else if isList v
    then concatStringsSep " " v
    else if isStringLike v
    then v
    else "";

  mkKeyValue = k: v: "${k} = ${mkValueString v}";

  mkKeyValuePairs = attrs: concatStringsSep "\n" (mapAttrsToList mkKeyValue attrs);
in
  mkKeyValuePairs

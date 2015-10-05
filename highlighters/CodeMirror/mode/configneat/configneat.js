CodeMirror.defineMode("configneat", function() {
  return {
    token: function(stream, state) {
      var sol = stream.sol();
      var ch = stream.next();

      var b = state.blocks[state.blocks.length - 1];

      if (sol) {
        b.linestart = true;
        b.linecomment = false;
      }

      if (state.error) return "error";

      if (ch == "\\" && !b.linecomment && !b.blockcomment) {
        if (stream.peek() == "`") {
          stream.next();
          return "string-2";
        }
      }

      if (ch == "%" && !b.linecomment && !b.blockcomment) {
        b.placeholder = !b.placeholder;
        return "placeholder";
      }

      if (b.placeholder) return "placeholder";

      if (ch == "`" && !b.linecomment && !b.blockcomment) {
        b.raw = !b.raw;
        return "quote";
      }

      if (b.raw) return "quote";

      if (ch == "#" && (b.was_space || b.linestart) && !b.blockcomment) {
        b.linecomment = true;
        return "comment";
      }

      if (b.linecomment) return "comment";

      if (ch == "/") {
        if (stream.peek() == "*") {
          b.blockcomment = true;
          return "comment";
        }
      }

      if (ch == "*" && b.blockcomment) {
        if (stream.peek() == "/") {
          stream.next();
          b.blockcomment = false;
          return "comment";
        }
      }

      if (b.blockcomment) return "comment";

      if (ch == "{") {
        state.blocks.push({
          key: true,
          key_start: undefined,
          linestart: true,
          paramstart: undefined,
          raw: false,
          placeholder: false,
          linecomment: false,
          blockcomment: false,
          was_space: false
        });
        return "bracket";
      }

      if (ch == "}") {
        if (state.blocks.length == 1) {
          state.error = true;
          return "error";
        }
        state.blocks.pop();
        return "bracket";
      }

      if ((ch == " ") && !b.linestart) {
        b.key_start = undefined;
        if (b.key) {
          b.key = false;
        }
      }

      b.was_space = (ch == " ");

      /* -1 to allow for non-hanging backtick before the first value */
      if ((ch != " ") && b.linestart && (!b.paramstart || (stream.pos < b.paramstart - 1))) {
        b.key = true;
        b.paramstart = undefined;
        b.linestart = false;
        b.key_start = b.ch = ch;
      }

      if ((ch != " ") && !b.key && !b.paramstart) {
        stream.backUp(1);
        // check if a known string is a single parameter
        // optionally followed by a whitespace, a line or a block comment
        if (stream.match(/(YES|Y|ON|TRUE|1)\s*((#|\/\*).*)?$/i, false)) {
          stream.match(/(YES|Y|ON|TRUE|1)/i, true);
          return "builtin";
        }
        if (stream.match(/(NO|N|OFF|FALSE|0)\s*((#|\/\*).*)?$/i, false)) {
          stream.match(/(NO|N|OFF|FALSE|0)/i, true);
          return "builtin";
        }
        stream.next();
      }

      if ((ch != " ") && !b.key && !b.paramstart) {
        b.paramstart = stream.pos;
      }

      if (b.key) {
        if (b.key_start == ":") return "key-label";
        if (b.key_start == "@") return "key-inherit";
        if (b.key_start == "+") return "key-merge";
        if (b.key_start == "-") return "key-delete";
        return "keyword";
      }

      return "variable";
    },

    startState: function() {
      return {
        blocks: [
          {
            key: true,
            key_start: undefined,
            linestart: true,
            paramstart: undefined,
            raw: false,
            placeholder: false,
            linecomment: false,
            blockcomment: false,
            was_space: false
          },
        ]
      };
    },
  };
});

CodeMirror.defineMIME("text/x-config-neat", "configneat");

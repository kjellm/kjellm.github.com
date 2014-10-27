---
title:      "Kjell-Magne Øierud :: Autocompile LaTeX documents"
date:       2014-10-28 17:39:00.00000 +01:00
layout:     bliki
---

A small shell snippet that will automatically run `pdflatex` when the source file is changed, and display a notification if it fails. The notification thing only works on OS X :-/

```sh
while true; do
  if [ cv.tex -nt cv.pdf ]; then
    pdflatex --interaction=nonstopmode cv.tex || \
      osascript -e 'display notification "Latex compilation failed" with title "ERROR"'
      sleep 1
  fi
done
```

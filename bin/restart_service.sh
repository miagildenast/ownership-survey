#!/bin/bash
set -x

supervisorctl reread
supervisorctl update
supervisorctl restart ownership_ash_chat

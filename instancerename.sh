#! /bin/bash
iris stop iris quietly
iris rename iris $1
iris start $1

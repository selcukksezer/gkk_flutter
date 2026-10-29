import base64, sys; s = sys.argv[3]; s += "=" * (-len(s) % 4); open(sys.argv[1], sys.argv[2] + "b").write(base64.b64decode(s))

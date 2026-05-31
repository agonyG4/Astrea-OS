import argparse
import json
import sys

from . import gmail


def print_json(payload):
    print(json.dumps(payload, ensure_ascii=False))


def normalize_argv(argv):
    args = list(sys.argv[1:] if argv is None else argv)
    if args and args[0] == "gmail":
        args = args[1:]
    return args


def build_parser():
    parser = argparse.ArgumentParser(description="Astrea Email backend CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("status")
    sub.add_parser("auth")

    list_parser = sub.add_parser("list")
    list_parser.add_argument("--folder", default="Inbox")
    list_parser.add_argument("--filter", default="all")
    list_parser.add_argument("--query", default="")
    list_parser.add_argument("--limit", default=30, type=int)
    list_parser.add_argument("--page-token", default="")
    list_parser.add_argument("--refresh", action="store_true")
    list_parser.add_argument("--no-cache", action="store_true")
    list_parser.add_argument("--cache-only", action="store_true")

    send_parser = sub.add_parser("send")
    send_parser.add_argument("--to", required=True)
    send_parser.add_argument("--subject", required=True)
    send_parser.add_argument("--body", default="")

    modify_parser = sub.add_parser("modify")
    modify_parser.add_argument("--id", required=True)
    modify_parser.add_argument("--action", required=True)

    get_parser = sub.add_parser("get")
    get_parser.add_argument("--id", required=True)
    get_parser.add_argument("--images", action="store_true")

    return parser


def main(argv=None):
    args = build_parser().parse_args(normalize_argv(argv))

    try:
        if args.command == "status":
            payload = gmail.status_payload()
        elif args.command == "auth":
            payload = gmail.auth_payload()
        elif args.command == "list":
            payload = gmail.list_messages(
                args.folder,
                args.filter,
                args.query,
                args.limit,
                args.page_token,
                force_refresh=args.refresh,
                use_cache=not args.no_cache,
                cache_only=args.cache_only,
            )
        elif args.command == "send":
            payload = gmail.send_message(args.to, args.subject, args.body)
        elif args.command == "modify":
            payload = gmail.modify_message(args.id, args.action)
        elif args.command == "get":
            payload = gmail.get_message(args.id, load_remote_images=args.images)
        else:
            raise gmail.GmailBridgeError(f"Unsupported command: {args.command}")

        print_json(payload)
        return 0
    except gmail.GmailBridgeError as exc:
        print_json({"ok": False, "provider": "gmail", "messages": [], "message": str(exc)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

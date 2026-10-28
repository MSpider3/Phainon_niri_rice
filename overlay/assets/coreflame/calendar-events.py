#!/usr/bin/env python3
# Prints the events between two ISO dates as JSON, read locally from Evolution Data Server
# (where GNOME Calendar keeps them): [{"summary","start","end","allDay","color"}].
# Prints [] and exits 0 when EDS or its Python bindings are missing, so the dashboard just shows none.
# usage: python3 -I calendar-events.py 2026-10-01 2026-11-01
import json
import sys
from datetime import datetime, timezone


def iso(t):
    if t.is_date():
        return "%04d-%02d-%02d" % (t.get_year(), t.get_month(), t.get_day())
    return datetime.fromtimestamp(t.as_timet_with_zone(t.get_timezone()), timezone.utc).astimezone().isoformat()


def events(start, end):
    import gi
    gi.require_version("EDataServer", "1.2")
    gi.require_version("ECal", "2.0")
    gi.require_version("ICalGLib", "3.0")
    from gi.repository import ECal, EDataServer, GLib

    out = []
    registry = EDataServer.SourceRegistry.new_sync(None)
    sources = registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR)
    pending = [len(sources)]
    loop = GLib.MainLoop()

    def done():
        pending[0] -= 1
        if pending[0] <= 0:
            loop.quit()

    # Each calendar takes a second or two to open, so open them all at once.
    def opened(_source, result, color):
        try:
            client = ECal.Client.connect_finish(result)

            def take(comp, s, e, *_):
                out.append({"summary": comp.get_summary() or "", "start": iso(s), "end": iso(e), "allDay": s.is_date(), "color": color})
                return True

            client.generate_instances_sync(int(start.timestamp()), int(end.timestamp()), None, take, None)
        except Exception:
            # One calendar failing (offline account, broken backend) must not hide the others.
            pass
        done()

    for source in sources:
        color = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR).get_color() or ""
        ECal.Client.connect(source, ECal.ClientSourceType.EVENTS, 1, None, opened, color)
    if sources:
        GLib.timeout_add_seconds(20, loop.quit)
        loop.run()
    # The same holiday or birthday often sits in several subscribed calendars; list it once.
    unique = {}
    for ev in sorted(out, key=lambda ev: ev["start"]):
        unique.setdefault((ev["summary"], ev["start"]), ev)
    return list(unique.values())


def main():
    try:
        start = datetime.fromisoformat(sys.argv[1]).astimezone()
        end = datetime.fromisoformat(sys.argv[2]).astimezone()
        print(json.dumps(events(start, end)))
    except Exception:
        print("[]")


if __name__ == "__main__":
    main()

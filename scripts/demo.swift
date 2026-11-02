#!/usr/bin/env swift
// Pilote la build Debug de Notch Usage par notifications distribuées (hooks `com.notchusage.debug.*`).
//
//   swift scripts/demo.swift <état>            # normal | pace | warning | critical | blocked | offline | reauth | off
//   swift scripts/demo.swift <état> snapshot   # capture l'encoche repliée dans $TMPDIR/notchusage-snapshot.png
//   swift scripts/demo.swift <état> panel      # idem, panneau déplié (survol simulé)
//   swift scripts/demo.swift hover=1 click=225,175 wait=2 snapshot   # commandes brutes, dans l'ordre
//
// Commandes brutes : demo=<état>, hover=0|1, click=<x>,<y> (points depuis le coin haut gauche), escape,
// snapshot, wait=<secondes>.
import Foundation

let states = ["normal", "pace", "warning", "critical", "blocked", "offline", "reauth", "off"]
var args = Array(CommandLine.arguments.dropFirst())
if let first = args.first, states.contains(first) {
    args.removeFirst()
    var expanded = ["demo=\(first)"]
    if args.first == "snapshot" { expanded += ["wait=1.5", "snapshot", "wait=1"]; args.removeFirst() }
    if args.first == "panel" { expanded += ["hover=1", "wait=1.5", "snapshot", "wait=1", "hover=0"]; args.removeFirst() }
    args = expanded + args
}
guard !args.isEmpty else {
    print("Usage : swift scripts/demo.swift <état> [snapshot|panel]  (états : \(states.joined(separator: ", ")))")
    exit(2)
}

let center = DistributedNotificationCenter.default()
for arg in args {
    let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
    if parts[0] == "wait" {
        Thread.sleep(forTimeInterval: Double(parts[1]) ?? 1)
        continue
    }
    center.postNotificationName(.init("com.notchusage.debug." + parts[0]), object: parts.count > 1 ? parts[1] : nil,
                                userInfo: nil, deliverImmediately: true)
    Thread.sleep(forTimeInterval: 0.3)
}
if args.contains("snapshot") {
    print(NSTemporaryDirectory() + "notchusage-snapshot.png")
}

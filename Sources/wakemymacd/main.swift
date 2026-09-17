// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation
import os
import WakeCore

let log = Logger(subsystem: DaemonConstants.machServiceName, category: "main")
log.info("wakemymacd \(DaemonConstants.version) starting (uid \(getuid()))")

let engine = SchedulerEngine()
engine.start()

let delegate = XPCListenerDelegate(engine: engine)
let listener = NSXPCListener(machServiceName: DaemonConstants.machServiceName)
listener.delegate = delegate
listener.resume()

dispatchMain()

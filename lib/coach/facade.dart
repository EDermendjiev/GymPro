// SPDX-License-Identifier: GPL-3.0-only
// The one door between the app's state and the coach packages: the app's own types go in, the app's own types
// or `Coach*` values come out. Package types never leave this layer by name.

/// Entry points are added as the modules land. It holds no state.
abstract final class CoachFacade {}

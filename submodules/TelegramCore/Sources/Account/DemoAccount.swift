import Foundation
import Postbox

/// Prepares the local database of a demo account. While it is set, accounts don't connect to the network.
public var demoAccountSetup: ((Postbox, Transaction) -> AuthorizedAccountState)?

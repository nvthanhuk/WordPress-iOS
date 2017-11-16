import Foundation
import WordPressFlux

enum PluginAction: WordPressFlux.Action {
    case activate(id: String, siteID: Int)
    case deactivate(id: String, siteID: Int)
    case enableAutoupdates(id: String, siteID: Int)
    case disableAutoupdates(id: String, siteID: Int)
    case remove(id: String, siteID: Int)
    case receivePlugins(siteID: Int, plugins: SitePlugins)
    case receivePluginsFailed(siteID: Int, error: Error)
}

struct PluginStoreState {
    var plugins = [Int: SitePlugins]()
    var fetching = [Int: Bool]()
}

class PluginStore: StatefulStore<PluginStoreState> {
    init(dispatcher: Dispatcher = .global) {
        super.init(initialState: PluginStoreState(), dispatcher: dispatcher)
    }

    func removeListener(_ listener: EventListener) {
        super.removeListener(listener)
        if listenerCount == 0 {
            // Remove plugins from memory if nothing is listening for changes
            state.plugins = [:]
        }
    }

    func getPlugins(siteID: Int) -> SitePlugins? {
        if let sitePlugins = state.plugins[siteID] {
            return sitePlugins
        }
        fetchPlugins(siteID: siteID)
        return nil
    }

    func getPlugin(id: String, siteID: Int) -> PluginState? {
        guard let sitePlugins = getPlugins(siteID: siteID) else {
            return nil
        }
        return sitePlugins.plugins.first(where: { $0.id == id })
    }

    override func onDispatch(_ action: Action) {
        guard let pluginAction = action as? PluginAction else {
            return
        }
        switch pluginAction {
        case .activate(let pluginID, let siteID):
            activatePlugin(pluginID: pluginID, siteID: siteID)
        case .deactivate(let pluginID, let siteID):
            deactivatePlugin(pluginID: pluginID, siteID: siteID)
        case .enableAutoupdates(let pluginID, let siteID):
            enableAutoupdatesPlugin(pluginID: pluginID, siteID: siteID)
        case .disableAutoupdates(let pluginID, let siteID):
            disableAutoupdatesPlugin(pluginID: pluginID, siteID: siteID)
        case .remove(let pluginID, let siteID):
            removePlugin(pluginID: pluginID, siteID: siteID)
        case .receivePlugins(let siteID, let plugins):
            receivePlugins(siteID: siteID, plugins: plugins)
        case .receivePluginsFailed(let siteID, _):
            state.fetching[siteID] = false
        }
    }
}

private extension PluginStore {
    func activatePlugin(pluginID: String, siteID: Int) {
        modifyPlugin(id: pluginID, siteID: siteID) { (plugin) in
            plugin.active = true
        }
        remote?.activatePlugin(
            pluginID: pluginID,
            siteID: siteID,
            success: {},
            failure: { [weak self] _ in
                self?.modifyPlugin(id: pluginID, siteID: siteID, change: { (plugin) in
                    plugin.active = false
                })
        })
    }

    func deactivatePlugin(pluginID: String, siteID: Int) {
        modifyPlugin(id: pluginID, siteID: siteID) { (plugin) in
            plugin.active = false
        }
        remote?.deactivatePlugin(
            pluginID: pluginID,
            siteID: siteID,
            success: {},
            failure: { [weak self] _ in
                self?.modifyPlugin(id: pluginID, siteID: siteID, change: { (plugin) in
                    plugin.active = true
                })
        })
    }

    func enableAutoupdatesPlugin(pluginID: String, siteID: Int) {
        modifyPlugin(id: pluginID, siteID: siteID) { (plugin) in
            plugin.autoupdate = true
        }
        remote?.enableAutoupdates(
            pluginID: pluginID,
            siteID: siteID,
            success: {},
            failure: { [weak self] _ in
                self?.modifyPlugin(id: pluginID, siteID: siteID, change: { (plugin) in
                    plugin.autoupdate = false
                })
        })
    }

    func disableAutoupdatesPlugin(pluginID: String, siteID: Int) {
        modifyPlugin(id: pluginID, siteID: siteID) { (plugin) in
            plugin.autoupdate = false
        }
        remote?.disableAutoupdates(
            pluginID: pluginID,
            siteID: siteID,
            success: {},
            failure: { [weak self] _ in
                self?.modifyPlugin(id: pluginID, siteID: siteID, change: { (plugin) in
                    plugin.autoupdate = true
                })
        })
    }

    func removePlugin(pluginID: String, siteID: Int) {
        guard let sitePlugins = state.plugins[siteID],
            let index = sitePlugins.plugins.index(where: { $0.id == pluginID }) else {
                return
        }
        state.plugins[siteID]?.plugins.remove(at: index)
        remote?.remove(
            pluginID: pluginID,
            siteID: siteID,
            success: {},
            failure: { [weak self] _ in
                _ = self?.getPlugins(siteID: siteID)
        })
    }

    func modifyPlugin(id: String, siteID: Int, change: (inout PluginState) -> Void) {
        guard let sitePlugins = state.plugins[siteID],
            let index = sitePlugins.plugins.index(where: { $0.id == id }) else {
                return
        }
        var plugin = sitePlugins.plugins[index]
        change(&plugin)
        state.plugins[siteID]?.plugins[index] = plugin
    }

    func fetchPlugins(siteID: Int) {
        guard !state.fetching[siteID, default: false],
            let remote = remote else {
                return
        }
        state.fetching[siteID] = true
        remote.getPlugins(
            siteID: siteID,
            success: { [globalDispatcher] (plugins) in
                globalDispatcher.dispatch(PluginAction.receivePlugins(siteID: siteID, plugins: plugins))
            },
            failure: { [globalDispatcher] (error) in
                globalDispatcher.dispatch(PluginAction.receivePluginsFailed(siteID: siteID, error: error))
        })
    }

    func receivePlugins(siteID: Int, plugins: SitePlugins) {
        state.plugins[siteID] = plugins
        state.fetching[siteID] = false
    }

    func receivePluginsFailed(siteID: Int) {
        state.fetching[siteID] = false
    }

    var remote: PluginServiceRemote? {
        let context = ContextManager.sharedInstance().mainContext
        let service = AccountService(managedObjectContext: context)
        guard let account = service.defaultWordPressComAccount() else {
            return nil
        }
        return PluginServiceRemote(wordPressComRestApi: account.wordPressComRestApi)
    }
}

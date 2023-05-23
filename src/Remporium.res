
type rec store<'state, 'action> = {
    mutable state: 'state,
    updateFunction: ('state, 'action) => 'state,
    subscription: array<(. unit) => unit>
}

module ReduxDevTools = {

    type rec messagePayload = {
        \"type": string
    }

    type rec subscribeMessage = {
        \"type": string,
        state: option<string>,
        payload: messagePayload,
    }

    type reduxDevTools
    @send external send: (reduxDevTools, string, 'state) => () = "send"
    @send external init: (reduxDevTools, 'state) => () = "init"
    @send external subscribe: (reduxDevTools, subscribeMessage => unit) => unit = "subscribe"

    type devToolsExtenstion
    @send external connect: (devToolsExtenstion) => reduxDevTools = "connect"

    let getDevTools = () => {
        let devToolsExtenstion: option<devToolsExtenstion> = %raw("window.__REDUX_DEVTOOLS_EXTENSION__")

        Belt.Option.map(devToolsExtenstion, x => connect(x))

    }
}


let dispatch = (store, action) => {
    store.state = store.updateFunction(store.state, action)

    Js.Array.forEach(e => e(.), store.subscription)
}
let subscribe = (store, f) => {
    Js.Array.push(f, store.subscription)->ignore
}

let unsubscribe = (store, f) => {
    let index = Js.Array.indexOf(f, store.subscription)
    Js.Array.spliceInPlace(~pos=index,~remove=1, ~add=[] ,store.subscription)->ignore
}

let makeStoreWithDevTools = (~actionName=?, initialState, updateFunction) => {

    let devToolsOption = ReduxDevTools.getDevTools()

    let devToolsUpdateFunction = switch devToolsOption {

    | None => {
        Js.Console.warn("Couldn't connect to redux-devtools, window.__REDUX_DEVTOOLS_EXTENSION__ not found")
        updateFunction
    }
    | Some(devTools) => {
        ReduxDevTools.init(devTools, initialState)

        (state, action) => {
            let res = updateFunction(state, action)
            
            let actionName = switch actionName {
            | None => "update"
            | Some(actionNameFn) => actionNameFn(action)
            }

            ReduxDevTools.send(devTools, actionName, res)
            res
        }
    }
    }

    let store = {
        state: initialState,
        updateFunction: devToolsUpdateFunction,
        subscription: []
    }

    if Belt.Option.isSome(devToolsOption) {
        ReduxDevTools.subscribe(devToolsOption->Belt.Option.getUnsafe, message => {

            if
                message.\"type" == "DISPATCH"
                && Belt.Option.isSome(message.state)
                && (message.payload.\"type" == "JUMP_TO_ACTION" || message.payload.\"type" == "JUMP_TO_STATE")
            {
                store.state = %raw("JSON.parse(message.state)")
                Js.Array.forEach(e => e(.), store.subscription)
            }
        })
    }

    store
}


let makeStore = (initialState, updateFunction) => {
    {
        state: initialState,
        updateFunction,
        subscription: []
    }
}

module type Config = {
  type state;
  type action;
};

module CreateModule = (Config: Config) => {

    let context = React.createContext(None)

    module Provider = {
        module InnerProvider = {
            let make = React.Context.provider(context)
        }

        @react.component
        let make = (~store, ~children) => <InnerProvider value=Some(store)> {children} </InnerProvider>
    }

    let useDispatch: (unit, Config.action) => unit = () => {
        let store = React.useContext(context)
        
        switch store {
        | Some(store) => 
            (action) => { dispatch(store, action) }
        | None => {
            failwith("store context not found, please ensure the component is wrapped in a <Provider>")
        }
        }
    }

    let useSelector: (Config.state => 'a) => 'a = selectorFunc => {

        let store = React.useContext(context)

        if Belt.Option.isNone(store) {
            failwith("store context not found, please ensure the component is wrapped in a <Provider>")
        }

        let store = Belt.Option.getUnsafe(store)
        let (selectedState, setState) = React.useState(() => selectorFunc(store.state))

        React.useLayoutEffect0(() => {

            let updateComponent = (.) => {
                setState(_ => selectorFunc(store.state))
            }

            subscribe(store, updateComponent)
            Some(() => {
                unsubscribe(store, updateComponent)
            })
        })

        selectedState
    }
}

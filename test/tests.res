open Test


@send external querySelector: (Dom.element, string) => Js.Nullable.t<Dom.element> = "querySelector"
@send external dispatchEvent: (Dom.element, Dom.event) => () = "dispatchEvent"

@send external appendChild: (Dom.element, Dom.element) => () = "appendChild"

let clickEvent: Dom.event = %raw(`
    new MouseEvent('click', { bubbles: true })
`)

let createElement: (string) => Dom.element = %raw(`function(el) {
    return window.document.createElement(el)
}
`)

let textContent: (Dom.element) => string = %raw(`function(el) {
    return el.textContent
}`)


let remove: (Dom.element) => unit = %raw(`function(el) { el.remove() }`)


let body: Dom.element = %raw(`window.document.body`)



let createContainer = () => { "div"->createElement }

let cleanupContainer = _ => {
    ()
}

let testWithReact = testWith(~setup=createContainer, ~teardown=cleanupContainer)
let testAsyncWithReact = testAsyncWith(~setup=createContainer, ~teardown=cleanupContainer)


module StoreConfig = {
    type action = Increment
    | Decrement
    | SetVal(string)

    type state = {
        counter: int,
        val: string
    }

    let state = { counter: 0, val: "" }

    let updateFunction = (state: state, action: action) => {
        switch action {
        | Increment => { ...state, counter: state.counter + 1 }
        | Decrement => { ...state, counter: state.counter - 1 }
        | SetVal(val) => { ...state, val }
        }
    }

}

module AppStore = Remporium.CreateModule(StoreConfig)

module Counter = {
    @react.component
    let make = () => {

        let dispatch = AppStore.useDispatch()
        let count = AppStore.useSelector(state => state.counter)

        <div>
            <button
                id="increment"
                onClick ={_ => dispatch(Increment)}
            >
            </button>
            <button
                id="decrement"
                onClick ={_ => dispatch(Decrement)}
            >
            </button>
            <span id="counter">{count->React.int}</span>
            <span id="randomValue">{Js.Math.random()->React.float}</span>
        </div>
    }
}

testWithReact("should rerender when value in useSelect changes", container => {

    let store = Remporium.makeStore(StoreConfig.state, StoreConfig.updateFunction)

    (() =>
        ReactDOM.render(
            <AppStore.Provider store=store>
                <Counter />
            </AppStore.Provider>,
            container,
        )
    )->ReactTestUtils.act


    let counterText = container
        ->querySelector("#counter")
        ->Js.Nullable.toOption
        ->Belt.Option.getUnsafe
        ->textContent

    assertion((a,b) => a == b, counterText, "0")

    (() => {
        container
            ->querySelector("#decrement")
            ->Js.Nullable.toOption
            ->Belt.Option.getUnsafe
            ->dispatchEvent(clickEvent)
    })->ReactTestUtils.act

    let counterText = container
        ->querySelector("#counter")
        ->Js.Nullable.toOption
        ->Belt.Option.getUnsafe
        ->textContent

    assertion((a,b) => a == b, counterText, "-1")

})



testWithReact("should unsubscribe from store", container => {

    let store = Remporium.makeStore(StoreConfig.state, StoreConfig.updateFunction)

    module Test = {
        @react.component
        let make = () => {
            let (show, setShow) = React.useState(() => true)

            <>
                <button id="setShow" onClick=(_ => {
                    setShow(_ => false)
                })>
                </button>
                { show ? <Counter />: React.null }
                <Counter />
            </>
        }
    }


    (() =>
        ReactDOM.render(
            <AppStore.Provider store=store>
                <Test />
            </AppStore.Provider>,
            container,
        )
    )->ReactTestUtils.act

    assertion((a,b) => a == b, store.subscription -> Js.Array.length, 2)

    (() => {
        container
            ->querySelector("#setShow")
            ->Js.Nullable.toOption
            ->Belt.Option.getUnsafe
            ->dispatchEvent(clickEvent)
    })->ReactTestUtils.act

    assertion((a,b) => a == b, store.subscription -> Js.Array.length, 1)


})



testWithReact("should rerender only when selected value changes", container => {

    let store = Remporium.makeStore(StoreConfig.state, StoreConfig.updateFunction)

    (() =>
        ReactDOM.render(
            <AppStore.Provider store=store>
                <Counter />
            </AppStore.Provider>,
            container,
        )
    )->ReactTestUtils.act


    let getRandomValue = () => {
        container
        ->querySelector("#randomValue")
        ->Js.Nullable.toOption
        ->Belt.Option.getUnsafe
        ->textContent
    }

    let randomValueBefore = getRandomValue()

    (() => {
        Remporium.dispatch(store, SetVal("some val"))
    })->ReactTestUtils.act

    let randomValueAfter = getRandomValue()

    assertion((a,b) => a == b, randomValueAfter, randomValueBefore)

})

module type Config = {
  type state;
};

module MockDevTools = (Config: Config) => {

    let initCall = ref(None)
    let init = (e: Config.state) => {
        initCall.contents = Some(e)
    }

    let subscribeFunc = ref(None)
    let subscribe = (func: Remporium.ReduxDevTools.subscribeMessage => unit) => {
        subscribeFunc.contents = Some(func)
    }

    let sendCall = ref(None)
    let send = (action: string, state: Config.state) => {
        sendCall.contents = Some((action, state))
    }

}


module TestMockDevTools = MockDevTools(StoreConfig)

test("should call reduxDevtools", () => {

    %raw("window.__REDUX_DEVTOOLS_EXTENSION__ = { connect: () => TestMockDevTools }")->ignore

    let store = Remporium.makeStoreWithDevTools(
        StoreConfig.state,
        StoreConfig.updateFunction,
    );

    assertion((a,b) => a == b, TestMockDevTools.initCall.contents, Some(StoreConfig.state))

    Remporium.dispatch(store, Increment)

    let expectedValue: StoreConfig.state = { counter: 1, val: "" }

    assertion((a,b) => a == b, TestMockDevTools.sendCall.contents, Some("update", expectedValue))


    {

        let message: Remporium.ReduxDevTools.subscribeMessage = {
            \"type": "DISPATCH",
            state: Some("{ \"counter\": 10, \"val\": \"\" }"),
            payload: { \"type": "JUMP_TO_ACTION" }
        }

        (TestMockDevTools.subscribeFunc.contents->Belt.Option.getExn)(message)

        let expectedValueAfterUpdate: StoreConfig.state = { counter: 10, val: "" }
        assertion(
            ~message="should update state when payloadType is JUMP_TO_ACTION",
            (a,b) => a == b, store.state, expectedValueAfterUpdate
        )

    }

    {

        let message: Remporium.ReduxDevTools.subscribeMessage = {
            \"type": "DISPATCH",
            state: Some("{ \"counter\": 11, \"val\": \"\" }"),
            payload: { \"type": "JUMP_TO_STATE" }
        }

        (TestMockDevTools.subscribeFunc.contents->Belt.Option.getExn)(message)

        let expectedValueAfterUpdate: StoreConfig.state = { counter: 11, val: "" }
        assertion(
            ~message="should update state when payloadType is JUMP_TO_STATE",
            (a,b) => a == b, store.state, expectedValueAfterUpdate
        )

    }

    {

        let message: Remporium.ReduxDevTools.subscribeMessage = {
            \"type": "DISPATCH",
            state: Some("{ \"counter\": 12, \"val\": \"\" }"),
            payload: { \"type": "SOME_PAYLOAD" }
        }

        (TestMockDevTools.subscribeFunc.contents->Belt.Option.getExn)(message)

        let expectedValueAfterUpdate: StoreConfig.state = { counter: 11, val: "" }
        assertion(
            ~message="should not update state when payload type is not JUMP_TO_STATE or JUMP_TO_ACTION",
            (a,b) => a == b, store.state, expectedValueAfterUpdate
        )

    }




    %raw("delete window.__REDUX_DEVTOOLS_EXTENSION__")->ignore
})



test("should call reduxDEvTools with name from name function", () => {

    %raw("window.__REDUX_DEVTOOLS_EXTENSION__ = { connect: () => TestMockDevTools }")->ignore


    let nameFunction = (action: StoreConfig.action) => {
        switch action {
        | Increment => "Increment"
        | Decrement => "Decrement"
        | SetVal(_) => "SetVal"
        }
    }

    let store = Remporium.makeStoreWithDevTools(StoreConfig.state, StoreConfig.updateFunction, ~actionName = nameFunction);

    {
        Remporium.dispatch(store, Increment)

        let (name, _) = TestMockDevTools.sendCall.contents->Belt.Option.getExn
        assertion((a,b) => a == b, name, "Increment")
    }

    {
        Remporium.dispatch(store, Decrement)

        let (name, _) = TestMockDevTools.sendCall.contents->Belt.Option.getExn
        assertion((a,b) => a == b, name, "Decrement")
    }


    %raw("delete window.__REDUX_DEVTOOLS_EXTENSION__")->ignore
})

test("should not throw when ther is not devtools installed", () => {


    Remporium.makeStoreWithDevTools(StoreConfig.state, StoreConfig.updateFunction)->ignore;

})

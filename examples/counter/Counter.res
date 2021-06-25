

type action = Increment | Decrement
type state = {
    count: int
}

let updateFunction = (state, action) => {
    switch action {
    | Increment => { count: state.count + 1 }
    | Decrement => { count: state.count - 1 }
    }
}

let initialState = {
    count: 0
}

let store = Remporium.makeStore(initialState, updateFunction)


module CounterStore = Remporium.CreateModule({
    type action = action
    type state = state
})



module Counter = {
  @react.component
  let make = () => {
      let dispatch = CounterStore.useDispatch()
      let count = CounterStore.useSelector(state => state.count)

      <div>
        <button onClick=(_ => dispatch(Increment))>
            {"Increment"->React.string}
        </button>
        <button onClick=(_ => dispatch(Decrement))>
            {"Decrement"->React.string}
        </button>
        <div>{count->React.int}</div>
      </div>

  }

}

ReactDOM.render(
  <CounterStore.Provider store=store>
    <Counter />
  </CounterStore.Provider>,
  ReactDOM.querySelector("#app") -> Belt.Option.getExn,
)

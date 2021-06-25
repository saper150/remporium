# Remporium

Redux inspired state management library for rescript-react

## Installation

```sh
# If you use npm:
npm install remporium

# Or if you use Yarn:
yarn add remporium
```

Add to `bsconfig.json`
```sh
"bs-dependencies": [
  "remporium"
]
```
When compiling your project make sure to add `-with-deps` flag to rescript compiler
```sh
rescript build -with-deps
```
## Basic setup

Define your state and actions
```ReScript
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
```
Next create store object and store module
```ReScript
let store = Remporium.makeStore(initialState, updateFunction)

module CounterStore = Remporium.CreateModule({
    type action = action
    type state = state
})
```
Add `CounterStore.Provider` component to the root of your react component tree
```ReScript
  <CounterStore.Provider store=store>
    {...}
  </CounterStore.Provider>,
```

## Hooks
Remporium provides 2 react hooks to use in your components `useDispatch` and `useSelector`

```ReScript
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
```

## Immutability
Remporium check for changes in state by performing shallow equality check, so make sure that your update function does not mutate state but returns new one

## DevTools
Remporium comes with support for redux-devtools via redux-devtools-extension(https://github.com/zalmoxisus/redux-devtools-extension)

To use redux devtools when creating store use `Remporium.makeStoreWithDevTools` function instead of `Remporium.makeStore`
```Rescript
let store = Remporium.makeStoreWithDevTools(initialState, updateFunction)
```

`Remporium.makeStoreWithDevTools` function takes optional `actionName` parameter. Because you can't serialize rescript variant to string this parameter is used to map actions to string that then are displayed in devtools, without it every action will be named `update`

```Rescript

let actionName = (action) => {
  switch action {
  | Increment => "Increment"
  | Decrement => "Decrement"
  }
}

let store = Remporium.makeStoreWithDevTools(initialState, updateFunction, ~actionName)
```

## Examples
For more examples check out examples folder

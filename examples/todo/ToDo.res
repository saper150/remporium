
module ToDoInput = {
    @react.component
    let make = () => {
        let dispatch = Store.useDispatch()
        let inputValue = Store.useSelector(state => state.todoInput)

        let handleInput = (e: ReactEvent.Form.t) => {
            ReactEvent.Form.target(e)["value"]->Store.SetToDoInput->dispatch
        }

        <form onSubmit=(e => {
            ReactEvent.Form.preventDefault(e)
            dispatch(Store.AddToDo)
        })>
            <input value=inputValue onChange=handleInput />
            <button>{"add todo"->React.string}</button>
        </form>

    }
}

module ToDoList = {
    @react.component
    let make = () => {
        let dispatch = Store.useDispatch()
        let todos = Store.useSelector(state => state.todos)

        <div>
            {Belt.Array.mapWithIndex(todos, (i, x) => 
            <div key=Js.Int.toString(i)>
                {x.name->React.string}
                <button onClick=(_ => Store.RemoveToDo(i)->dispatch) >{"X"->React.string}</button>
            </div>
            )->React.array}
        </div>
    }
}

ReactDOM.render(
    <Store.Provider store=Store.store>
        <ToDoInput />
        <ToDoList />
    </Store.Provider>,
    ReactDOM.querySelector("#app") -> Belt.Option.getExn,
)

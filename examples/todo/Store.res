
type rec todo = {
    name: string
}

module StoreConfig = {
    type action = SetToDoInput(string) | AddToDo | RemoveToDo(int)
    type state = {
        todoInput: string,
        todos: array<todo>
    }

    let state = { todoInput: "", todos: [] }

    let updateFunction = (state: state, action: action) => {
        switch action {
        | SetToDoInput(todoInput) => { ...state, todoInput: todoInput }
        | AddToDo => {
            todoInput: "",
            todos: Js.Array.concat(state.todos, [{ name: state.todoInput }])
        }
        | RemoveToDo(index) => {
            ...state,
            todos: Js.Array.filteri((_, i) => i!== index, state.todos)
        }
        }
    }

}

include StoreConfig
include Remporium.CreateModule(StoreConfig)

let actionName = (action) => {
    switch action {
    | SetToDoInput(_) => "SetToDoInput"
    | AddToDo => "AddToDo"
    | RemoveToDo(_) => "RemoveToDo"
    }
}

let store = Remporium.makeStoreWithDevTools(StoreConfig.state, StoreConfig.updateFunction, ~actionName)

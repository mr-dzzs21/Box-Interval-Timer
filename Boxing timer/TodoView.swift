//
//  TodoView.swift
//  Boxing timer
//

import SwiftUI

struct TodoView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var todoManager: TodoManager

    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool

    var openTodos: [Todo] { todoManager.todos.filter { !$0.isDone } }
    var doneTodos: [Todo] { todoManager.todos.filter { $0.isDone } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Eingabezeile
                HStack(spacing: 12) {
                    TextField(lang.t.todoPlaceholder, text: $newTitle)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { addTodo() }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Button(action: addTodo) {
                        Text(lang.t.todoAdd)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                if todoManager.todos.isEmpty {
                    // Leerer Zustand
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(lang.t.todoEmpty)
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text(lang.t.todoEmptyDesc)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        // Offene Todos
                        if !openTodos.isEmpty {
                            Section(lang.t.todoOpen) {
                                ForEach(openTodos) { todo in
                                    TodoRow(todo: todo)
                                        .onTapGesture { todoManager.toggle(todo) }
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { openTodos[$0].id }
                                    todoManager.todos.removeAll { ids.contains($0.id) }
                                    save()
                                }
                            }
                        }

                        // Erledigte Todos
                        if !doneTodos.isEmpty {
                            Section(lang.t.todoDone) {
                                ForEach(doneTodos) { todo in
                                    TodoRow(todo: todo)
                                        .onTapGesture { todoManager.toggle(todo) }
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { doneTodos[$0].id }
                                    todoManager.todos.removeAll { ids.contains($0.id) }
                                    save()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(lang.t.todosTitle)
            .navigationBarTitleDisplayMode(.large)
            .onTapGesture { fieldFocused = false }
        }
    }

    private func addTodo() {
        todoManager.add(newTitle)
        newTitle = ""
        fieldFocused = false
    }

    private func save() {
        if let data = try? JSONEncoder().encode(todoManager.todos) {
            UserDefaults.standard.set(data, forKey: "todos")
        }
    }
}

struct TodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(todo.isDone ? .green : .gray)

            Text(todo.title)
                .strikethrough(todo.isDone, color: .gray)
                .foregroundColor(todo.isDone ? .gray : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

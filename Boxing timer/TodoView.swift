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
                        .foregroundColor(.white)
                        .tint(DS.accent)
                        .padding(12)
                        .background(DS.surfaceHi)
                        .cornerRadius(10)

                    Button(action: addTodo) {
                        Text(lang.t.todoAdd)
                            .fontWeight(.bold)
                            .foregroundColor(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? DS.textTertiary : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? DS.surfaceHi : DS.accent)
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
                            .font(.system(size: 56))
                            .foregroundColor(DS.textTertiary)
                        Text(lang.t.todoEmpty)
                            .font(DS.display(22))
                            .foregroundColor(.white)
                        Text(lang.t.todoEmptyDesc)
                            .font(.subheadline)
                            .foregroundColor(DS.textSecondary)
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
                                        .listRowBackground(DS.surface)
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { openTodos[$0].id }
                                    todoManager.delete(ids: ids)
                                }
                            }
                        }

                        // Erledigte Todos
                        if !doneTodos.isEmpty {
                            Section(lang.t.todoDone) {
                                ForEach(doneTodos) { todo in
                                    TodoRow(todo: todo)
                                        .onTapGesture { todoManager.toggle(todo) }
                                        .listRowBackground(DS.surface)
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { doneTodos[$0].id }
                                    todoManager.delete(ids: ids)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle(lang.t.todosTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture { fieldFocused = false }
        }
    }

    private func addTodo() {
        todoManager.add(newTitle)
        newTitle = ""
        fieldFocused = false
    }
}

struct TodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(todo.isDone ? DS.accent : DS.textTertiary)

            Text(todo.title)
                .strikethrough(todo.isDone, color: DS.textTertiary)
                .foregroundColor(todo.isDone ? DS.textSecondary : .white)

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

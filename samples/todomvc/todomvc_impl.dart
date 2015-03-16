import 'model.dart';
import 'dart/todomvc_presenter.dart';
import 'dart/todomvc_presenter_model.dart';

class TodoMVCImpl extends TodoMVCPresenter {

  Model _model = new Model();

  TodoMVCImpl() {
    _model.createItem("My default todo");
    _model.createItem("Some other todo");
  }

  void createItem(title) {
    _model.createItem(title.str);
  }

  void deleteItem(int id) {
    _model.deleteItem(id);
  }

  void completeItem(int id) {
    _model.completeItem(id);
  }

  void uncompleteItem(int id) {
    _model.uncompleteItem(id);
  }

  void clearItems() {
    _model.clearItems();
  }

  Immutable render() {
    Immutable list = new Nil();
    for (var i = _model.todos.length; i > 0; ) {
      list = new Cons(_reprItem(_model.todos[--i]), list);
    }
    return list;
  }

  Immutable _reprItem(Item item) =>
      new Cons(new Str(item.title),
               new Bool(item.done));

}

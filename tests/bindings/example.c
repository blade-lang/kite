#include <blade.h>

b_value example_field(b_vm *vm) {
  return NUMBER_VAL(0);
}

DECLARE_MODULE_METHOD(example_function) {
  RETURN;
}

CREATE_MODULE_LOADER(example) {

  static b_field_reg fields[] = {
    {"field", false, example_field},
    {NULL, false, NULL},
  };

  static b_func_reg functions[] = {
      {"function",   true,  GET_MODULE_METHOD(example_function)},
      {NULL,    false, NULL},
  };

  static b_module_reg module = {
      .name = "example",
      .fields = fields,
      .functions = functions,
      .classes = NULL,
      .preloader = NULL,
      .unloader = NULL
  };

  return &module;
}

int main() {
  return 0;
}

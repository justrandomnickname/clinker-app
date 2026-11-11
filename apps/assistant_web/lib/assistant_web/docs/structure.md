# assistant_web

Корень `lib/assistant_web` держит вход приложения и четыре папки:

- `shell` — каркас страницы и страницы ошибок
- `shared` — общее для страниц и компоненты, которые нужны двум и более фичам
- `features` — фичи. У чата это `features/chat/pages` и `features/chat/components`
- `docs` — заметки по устройству

`endpoint.ex`, `router.ex`, `application.ex` и `api_controller.ex` остаются в корне: это вход, а не экран.

Как устроена страница и за что отвечают `Screen`, `Event`, `Request` и `Log`: [page.md](page.md).

Тест лежит рядом со страницей или компонентом, который проверяет. `test/` остаётся для общих компонентов и входа приложения.

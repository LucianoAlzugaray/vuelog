:- module(render, [meal_plan_page//1]).

:- use_module(library(http/html_write), [html//1, html_post//2]).
:- use_module(library(http/js_write), [javascript/4, js_expression//1]).
:- use_module(library(http/json), [atom_json_term/3]).
:- use_module(library(css_write), [css//1, write_css/2]).
:- use_module(library(list_util), [replicate/3]).

:- use_module(util, [ts_day/2]).

% Helper predicates

include_css(CssDcg) -->
    { write_css(CssDcg, CssTxt) },
    html_post(css, style([], CssTxt)).

include_js(JsTxt) -->
    html_post(js, html(JsTxt)).

:- meta_predicate listof(//, +).
%% listof(DCG//1, Elements) generates a list of elements from a DCG
%% (presumably html//1) to make them work with Quench Vue.
listof(DCG, Elements) -->
    listof(DCG, Elements, true).
listof(_, [], _) --> [].
listof(DCG, [E|Rest], true) -->
    call(DCG, E), listof(DCG, Rest, false).
listof(DCG, [E|Rest], false) -->
    ["<!-- <q> -->"],
    call(DCG, E),
    ["<!-- </q> -->"],
    listof(DCG, Rest, false).

% Rendering pages

main_js(State) -->
    include_js(
        script(type('text/javascript'),
               {|javascript(State)||
                var appEl = document.getElementById('app');
                var template = quenchVue.createAppTemplate(appEl);
                var app = new Vue(
                  {el: appEl,
                   data: State,
                   template: template,
                   methods: {addMeal: function(event) {
                     let name = event.target.elements["name"].value;
                     app.meals.push({name: name});
                     event.target.elements["name"].value = "";
                   }}
                  });
     |})).

meal_plan_page(State) -->
    html([div([id(app)],
              [div(class('parameters'),
                   [label(["Start Date",
                           input([type(date), 'v-model'(start_day),
                                  value(State.start_day)], [])]),
                    label(["End Date",
                           input([type(date), 'v-model'(end_day),
                                 value(State.end_day)], [])]),
                    label(["Meals per day",
                           input([type(number), 'v-model'(meals_per_day),
                                  value(State.meals_per_day)], [])])]),
               div(class(meals), \meals(State)),
               div(class(schedule), [h2("Schedule"), \calendar(State)])]),
          \main_js(State)]).

meals(State) -->
    html([h2("Menu Options"),
          ul(\meal_items(State.meals)),
          \add_meal]).

meal_items(Meals) --> listof(meal_item, Meals).
meal_item(Meal) -->
    html(li([class(meal), 'v-for'("meal in meals"),
             'v-text'("meal.name")],
            Meal.name)).

add_meal -->
    html(form(['@submit.prevent'("addMeal")],
              [input([type(text), name(name), placeholder('Food name')]),
              input([type(submit), value('Add')])])).

calendar_css -->
    css(['.calendar'(
             [display(flex),
              'flex-direction'(row)],
             '.day'([margin('0.5em')],
                    '.meal-slot'([width('2em'),
                                  height('2em'),
                                  margin('0.5em'),
                                  'background-color'(green)])))]).

% TODO: figure out how to make the calendar change...
calendar(State) -->
    { ts_day(StartTs, State.start_day),
      ts_day(EndTs, State.end_day) },
    html([\include_css(calendar_css),
          div(class(calendar),
              \calendar_items(State.meals_per_day, StartTs, EndTs))]).

calendar_items(_, D, D) --> [].
calendar_items(NSlots, S, E) -->
    { Next is S + 3600*24,
      replicate(NSlots, div(class('meal-slot'), []), Slots),
      ts_day(S, Day) },
    html(div(class(day),
             [span(Day)|Slots])),
    calendar_items(NSlots, Next, E).
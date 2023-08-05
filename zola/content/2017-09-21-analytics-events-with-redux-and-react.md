+++
layout = "post"
title = "Logging analytics events in a testable way with React and Redux"
date = "2017-09-21 09:36:15"
categories = "web"
image = "logging-header.jpg"
+++

One of my main responsibilites at [TotallyMoney](https://www.totallymoney.com/) was to take care of
the in-house analytics/event logging framework. Like lots of companies, understanding what users do
and how they interact with a product is to get good insight on. In this regard, people reinvent the
logging wheel with various [krimskrams](https://en.wiktionary.org/wiki/krimskrams) attached, me
being no exception. What I want to show in this post is how to integrate an event logging framework
into a React/Redux application in a way that's scaleable and testable. Unit testable logging is
important when the rest of the business relies heavily on the events and the data in them like many
companies do.

tl;dr: pass your logger to React's `context` to make logging from deeply nested components much
easier.

In this article, I'm assuming you've got an existing React/Redux application, and want to integrate
some kind of event logging library into it.

## The logging library

Let's make a fake logging library that looks like this:

```javascript
// lib/logger.js

class Logger {
  constructor() {
    this.socket = new WebSocket("wss://events.example.com");
  }

  send(eventName, eventData = {}) {
    this.socket.send({
      eventName,
      payload: eventData,
    });
  }
}

export default new Logger();
```

This could be anything, even something like Google Analytics or Firebase. How you log events and to
where doesn't really matter as the logging code will be contained inside an action creator.

## Redux – Action creator

Action creators in Redux can have side effects like making API calls or, in our case, logging
something. We'll create a simple action creator like this:

```javascript
// actions/logger.js

import logger from '../lib/logger'

export const LOG_EVENT = 'LOG_EVENT'

export function logEvent(name, data❶ = {}) {
	logger.send(name, data)

	return❷ {
		type: LOG_EVENT,
		name,
		data,
	}
}
```

❶ Define a default empty object, so we don't have to worry about handling undefined or null values.

❷ Returning something from this action creator isn't strictly necessary for just logging events
using the logger, but if you want to record those events in your Redux store, you need to return an
action for the reducers to respond to.

We now have an action creator that, when called, will log an event over our pretend websocket-based
logging library. Let's hook it up to a button in React.

## Integration with React (the bad way)

The simplest and perhaps obvious way is to pass down an event handler to the elment you want to log
an event from. React encourages this pattern for handling other events, so why not logs? When an
event is fired, your code would handle that in the top level Redux-connected page component. We
could pepper Redux' `connect()` through our component tree, but that makes testing _harder_, which
is the opposite of what we want to do. It also tightly couples our app to Redux instead of dealing
with plain old Javascript objects.

This following example is for a login page where we want to log an event when the submit button is
clicked. Here, logging that event isn't too bad because we already have a click handler for the
submit button. But what if we had a different component with no other props? In this case, we'd have
to write a `handleClick` function in the top level component, and pass an `onClick` prop all the way
through the component tree. This is noisy, boilerplate-y and error prone. In the next section, I'll
show a better way of doing this.

```javascript
// pages/Login.jsx

import React, { PureComponent } from 'react'

import { logEvent } from '../actions/logger'

const SubmitButton = ({ onClick, children }) => (
	<button
		className="btn btn--submit"
		onClick={onClick}
	>
		{children}
	</button>
)

const LoginForm = ({ onSubmit, onChange }) => (
	<form>
		<input
			onChange={onChange}
			type="text"
			name="email"
		/>

		<input
			onChange={onChange}
			type="password"
			name="password"
		/>

		<SubmitButton onClick={onSubmit}>
			Log in
		</SubmitButton>
	</form>
)

class LoginPage extends PureComponent {
	handleChange(e) {
		...
	}

	handleSubmit() {
		const { dispatch } = this.props

		dispatch(logEvent('loginSubmit'))
		dispatch(login())
	}

	render() {
		return (
			<main>
				<header>...</header>

				<LoginForm
					onChange={this.handleChange}
					onSubmit={this.handleSubmit}
				/>
			</main>
		)
	}
}

export default connect(state => state)(LoginPage)
```

## Integration with React (the ~~good~~ better way)

A better way to handle this logging is to use React's
[context](https://facebook.github.io/react/docs/context.html) functionality. Context
[should be used sparingly](https://facebook.github.io/react/docs/context.html#why-not-to-use-context)
and its caveats like coupling global state, but in this case it can help us create a far cleaner
logging implementation. First, we need to make a context provider that will make the logger
available to all child components in our app:

```javascript
// components/LoggerProvider.jsx

import React, { PureComponent } from 'react'

import { logEvent } from '../actions/logger'

class LoggerProvider extends PureComponent {
	❶static childContextTypes = {
		logEvent: PropTypes.func,
	}

	❷getChildContext = () => {
		return {
			logEvent: (eventName, eventData) => this.props.store.dispatch(logEvent(eventName, eventData)),
		}
	}

	// Pass through children verbatim
	render = () => this.props.children
}

export default connect(() => {}❸)(LoggerProvider)
```

Here we:

❶ Define `childContextTypes` to allow child components to ask for `logEvent` using their
`contextTypes` property.

❷ Make the definition of `logEvent`. In this case, it's a function that will be called like
`context.logEvent('foo', { bar: 'true '})` which matches the Redux action signature written earlier.

❸ Don't need any state from the store, so we can just return an empty object.

This component won't work without a Redux store. We can add that by wrapping it in a `Provider`
component from [`react-redux`](https://npmjs.com/package/react-redux). An example application might
look like this:

```javascript
// index.jsx

import React from "react";

import { Provider } from "react-redux";

const App = ({ store }) => (
  <Provider store={store}>
    <LoggerProvider>{/* Insert your router or page container component here */}</LoggerProvider>
  </Provider>
);
```

Make sure `LoggerProvider` is a child of `Provider`. If it's the other way round, you won't be able
to access the store. Now let's modify the `<SubmitButton />` component we want to log events from to
give it access to `context`:

```javascript
// components/LoginButton.jsx

import PropTypes from 'prop-types'

const SubmitButton = ({ onClick, children }, { logEvent❶ }) => (
	<button
		className="btn btn--submit"
		onClick={onClick}
	>
		{children}
	</button>
)

❷SubmitButton.contextTypes = {
	logEvent: PropTypes.func,
}

export default SubmitButton
```

❶ Stateless functional components access `context` through the second argument of the function
declaration.

❷ React requires you to explicitly mark which pieces of the context you want using
`Component.contextTypes`. In this case, just `logEvent` which is a function. If you don't add this,
`logEvent` will be undefined!

Assuming your app uses `LoggerProvider` somewhere near the top of its component tree, you should now
be able to call `context.logEvent` which will dispatch a Redux action with the functionality
provided by `LoggerProvider`. This should work wherever this component is in the component tree.

## Testing with Mocha and Enzyme

Easy testability is a very useful side-effect of using the context method. You could add spies and
assertions around a Redux store, but this then requires you to store logged events in your store
which you might not want to do (e.g. with third party logging libraries). It also leads to a much
more complex test harness involving Redux and a `<Provider>`.

I'm using [Mocha](http://mochajs.org/), [Enzyme](http://airbnb.io/enzyme/),
[Chai](http://chaijs.com/) and [Sinon](http://sinonjs.org/) for this article, but this technique
should be applicable to most test environments.

Using `context` in a component comes with the caveat that a context obejct must be present in Enzyme
unit tests. This can get a little frustrating and introduces some obtuse errors if one is not aware
of the `context` requirement. However I think the benefits outweigh these extra steps. Context
[can easily be passed into components](http://airbnb.io/enzyme/docs/api/shallow.html#arguments),
making it extremely simple to pass spies and catch logging calls.

It's not strictly necessary, but I'm going to use
[`sinon-chai`](https://github.com/domenic/sinon-chai) to make error messages a bit clearer.

Here's our test:

```javascript
// test/components/SubmitButton.spec.js

import SubmitButton from "../components/SubmitButton";

describe("<SubmitButton />", () => {
  it("Calls the onClick event when clicked", () => {
    const clickSpy = spy();

    const button = shallow(<SubmitButton onClick={clickSpy}>Submit</SubmitButton>, {
      context: { logEvent: () => {} },
    });

    button.simulate("click");

    expect(clickSpy).to.have.been.calledOnce;
  });

  it("Logs an event when clicked", () => {
    const logSpy = spy();

    const button = shallow(<SubmitButton onClick={() => {}}>Submit</SubmitButton>, {
      context: { logEvent: logSpy },
    });

    button.simulate("click");

    expect(logSpy).to.have.been.calledWith("loginSubmit", { foo: "bar", baz: "quux" });
  });
});
```

We've got two tests here:

1. `Calls the onClick event when clicked`. Checks to make sure `onSubmit()` is called when the
   button is clicked. This isn't relevant to event log testing, it just shows another Enzyme test
   being used.

2. `Logs an event when clicked`. Checks that `logEvent` was called, and with the correct arguments.
   `.calledWith('loginSubmit', { foo: 'bar', baz: 'quux' })` should be replaced with whatever shape
   of event you're logging. In this example, it's hardcoded to
   `('loginSubmit', { foo: 'bar', baz: 'quux' })`.

If you've set everything up right, you should see something like this:

```
  <SubmitButton />
    ✓ Calls the onClick event when clicked
    ✓ Logs an event when clicked


  2 passing (2ms
```

Hooray!

## Conclusion

React's `context` can be pretty powerful when used sparingly. Here, I've presented an approach to
event collection that makes logging from deeply nested React nodes easier, simpler and more
testable. However, I think it's important to take multiple approaches to event logging depending on
where the event needs to be fired from. If you can do it without using `context`, do that! You lose
some ability to test using a spy in your tests, but it makes component testing simpler with less
configuration by not requiring a fake context. If you can log an event inside another action
creator, that's the best way to go if possible. If not, using a context provider leads to a more
scalable approach for larger apps with deeply nested component trees.

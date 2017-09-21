---
layout: post
title:  "Logging analytics events in a testable way with React and Redux"
date:   2017-09-21 09:36:15
categories: web,javascript
image: logging-header.jpg
---

One of my main responsibilites at [TotallyMoney](https://www.totallymoney.com/) was to take care of the in-house analytics/event logging framework. Like lots of companies, understanding what users do and how they interact with a site is an important thing to get good insight on, so people reinvent the wheel with various [krimskrams](https://en.wiktionary.org/wiki/krimskrams) attached, me being no exception. What I want to show in this post is how to integrate an event logging framework into a React/Redux application in a way that's scaleable and reasonably unit testable. Unit tests are important for event logging when the rest of the business relies on both the events being sent, and with the correct data!

In this article, I'm assuming you've got an existing React/Redux application, and want to integrate some kind of event logging library (third party or otherwise) into it.

## The logging library

Let's make a fake logging library that looks like this:

```javascript
// lib/logger.js

class Logger {
	constructor() {
		this.socket = new WebSocket(
			'wss://events.example.com'
		)
	}

	send(eventName, eventData = {}) {
		this.socket.send({
			eventName,
			payload: eventData,
		})
	}
}

export default new Logger()
```

This could be anything, even something like Google Analytics or Firebase. How you log events and to where doesn't really matter as the logging code will be contained inside an action creator.

## Redux – Action creator

Action creators in Redux can have side effects like making API calls or, in our case, logging something. We'll create a simple action creator like this:

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

❷ Returning something from this action creator isn't strictly necessary for just logging events using the logger, but if you want to record those events in your Redux store, you need to return an action for the reducers to respond to.

We now have an action creator that, when called, will log an event over our pretend websocket-based logging library. Let's hook it up to a button in React.

## Integration with React (the bad way)

The first, simpler way is to pass down an event handler to the elment you want to log an event from, then handle that in your top level Redux-connected page component. It's good practice to not use Redux' `connect()` anywhere but in the top level component, so in the following code we pass down an event handler to log an event when the submit button is clicked on a pretend login form.

This approach works quite well for shallowly nested components, but begins to break down quite quickly with deeper nested trees. It is particularly noisy and cumbersome when an event needs to be logged at the bottom of a tree of static components. In that case, this method requires passing down an event handler all the way to the target element _for the sole purpose of logging an event_. This is noisy, introduces subtle bugs and requires a pile of boilerplate to implement. The next section discusses a better way of doing this.

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

## Testing with Mocha and Enzyme
---
layout: post
title:  "Better testing with ES6 default arguments"
date:   2018-01-03 16:54:02
categories: javascript
image: huanyang-header-2.jpg
---

Default arguments are one of the many swag things that have come out of ES6. They allow functions to be shorter and more concise, moving the traditional undefined checks into the function arguments. One way to use default args is to pass in things like API clients or other bits of code that depend on third party services. This allows the programmer to unit test functions that would otherwise require external dependencies or rely on third party APIs.

## First off

Below is some JavaScript we want to test. It makes an HTTP GET request to a hypothetical REST API that returns a user by ID. All pretty normal stuff.

```javascript
async function doHttpRequest(url) {
	return await fetch(url)
		.then(response => response.json())
}

async function findUser(id) {
	const user = await doHttpRequest(`/users/${id}`)
}
```

This is a problem to test because it makes an HTTP request. One way to fix this is to intercept or mock the request or response. I've done this before and it works ok, but the amount of boilerplate code around the test I find grows quite quickly.

## Dependency injection

Here's a better idea:

```javascript
// userUtils.js

async function doHttpRequest(url) {
	return await fetch(url)
		.then(response => response.json())
}

export async function findUser(id, requester = doHttpRequest) {
	const user = await requester(`/users/${id}`)

	return user
}
```

Not much has changed, but now instead of directly calling `doHttpRequest`, we've injected it into the function with a default argument. The function signature from the caller's perspective hasn't changed (it's still just `findUser(111)`) but now we're free to change what `requester` does in our tests. I'm going to use Mocha, Chai and Sinon in the following examples, but they should translate pretty easily to your test framework of choice. I'm also using async/await because it's kickass.

Here's what a typical Mocha test looks like using Sinon to stub out the requester function:

```javascript
import { spy, stub } from 'sinon'
import { expect } from 'chai'

import { findUser } from '/path/to/userUtils.js'

describe('Find users by ID', () => {
	const fakeUser = { userId: 111, username: 'wapl.es' }
	const requestStub = stub().resolves(fakeUser)

	it("Calls the REST endpoint with an ID", async () => {
		const requestSpy = spy(requestStub)

		await findUser(111, requestSpy)

		expect(requestSpy.calledWith('/users/111')).to.be.true
	})

	it("Returns the user from the response", async () => {
		const requestSpy = spy(requestStub)

		const user = await findUser(111, requestSpy)

		expect(user).to.equal(fakeUser)
	})
})
```

Benefits:

- Good: Because you're just dealing with data and a function call, you can swap out the requester more easily. Switch to websockets, or maybe it reads/writes to/from a file. You'd have to rewrite a lot of the test boilerplate if it was mocked as an HTTP service
- Good: Moves assertions back into familiar land like Chai, allowing you to use more flexible assertions in a familiar way
- Good: Fewer libs. You're probably using Sinon anyway.

- Bad: Isn't actually HTTP. Maybe you need to exercise your HTTP stack. In this case, the above isn't a good solution

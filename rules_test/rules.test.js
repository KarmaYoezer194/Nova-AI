// Tests for ../firestore.rules, run against the local Firestore emulator.
//
// Run from the nova folder:   cd rules_test; npm test
// (Needs Java. The emulator uses a fake "demo-" project, so these tests
// never touch the real database.)
//
// Each test acts as a signed-in user ("alice"), another user ("bob") or
// nobody, and checks that the rules allow or refuse the request.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nova',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const nobody = () => env.unauthenticatedContext().firestore();

/** Creates alice's chat "c1" the way the app does. */
async function aliceChat(extra = {}) {
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice/conversations/c1'), {
      title: 'Hello',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...extra,
    }),
  );
}

describe('only the owner can reach their data', () => {
  test('owner can create and read their chat', async () => {
    await aliceChat();
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/conversations/c1')));
  });

  test('another user cannot read, write or delete it', async () => {
    await aliceChat();
    const path = 'users/alice/conversations/c1';
    await assertFails(getDoc(doc(bob(), path)));
    await assertFails(updateDoc(doc(bob(), path), { title: 'Hacked' }));
    await assertFails(deleteDoc(doc(bob(), path)));
  });

  test('signed-out visitors get nothing', async () => {
    await aliceChat();
    await assertFails(getDoc(doc(nobody(), 'users/alice/conversations/c1')));
  });

  test('anything outside users/{uid} is blocked', async () => {
    await assertFails(setDoc(doc(alice(), 'public/x'), { a: 1 }));
    await assertFails(
      setDoc(doc(alice(), 'users/alice/secrets/x'), { a: 1 }),
    );
  });
});

describe('messages', () => {
  const msg = (data) =>
    setDoc(doc(alice(), 'users/alice/conversations/c1/messages/m1'), {
      createdAt: serverTimestamp(),
      ...data,
    });

  test('a normal message is allowed', async () => {
    await aliceChat();
    await assertSucceeds(msg({ role: 'user', text: 'Hi' }));
  });

  test('size limits: 20,000 for user, 100,000 for model', async () => {
    await aliceChat();
    await assertFails(msg({ role: 'user', text: 'x'.repeat(20001) }));
    await assertSucceeds(msg({ role: 'model', text: 'x'.repeat(100000) }));
    await assertFails(msg({ role: 'model', text: 'x'.repeat(100001) }));
  });

  test('wrong role, empty text or extra fields are refused', async () => {
    await aliceChat();
    await assertFails(msg({ role: 'admin', text: 'Hi' }));
    await assertFails(msg({ role: 'user', text: '' }));
    await assertFails(msg({ role: 'user', text: 'Hi', isAdmin: true }));
  });

  test('a fake time is refused (must be the server time)', async () => {
    await aliceChat();
    await assertFails(
      setDoc(doc(alice(), 'users/alice/conversations/c1/messages/m1'), {
        role: 'user',
        text: 'Hi',
        createdAt: new Date('2020-01-01'),
      }),
    );
  });

  test('attachment note: only on user messages, image or pdf', async () => {
    await aliceChat();
    await assertSucceeds(
      msg({ role: 'user', text: 'Hi', attachmentKind: 'pdf', attachmentName: 'a.pdf' }),
    );
    await assertFails(msg({ role: 'model', text: 'Hi', attachmentKind: 'pdf' }));
    await assertFails(msg({ role: 'user', text: 'Hi', attachmentKind: 'exe' }));
  });

  test('messages can never be edited', async () => {
    await aliceChat();
    await assertSucceeds(msg({ role: 'user', text: 'Hi' }));
    await assertFails(
      updateDoc(doc(alice(), 'users/alice/conversations/c1/messages/m1'), {
        text: 'Changed',
      }),
    );
  });

  test('the app\'s batch (message + updatedAt) is allowed', async () => {
    await aliceChat();
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, 'users/alice/conversations/c1/messages/m2'), {
      role: 'model',
      text: 'Answer',
      createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'users/alice/conversations/c1'), {
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });
});

describe('profile, memories and projects', () => {
  test('custom instructions: up to 2,000 characters', async () => {
    const user = (text) =>
      setDoc(doc(alice(), 'users/alice'), {
        createdAt: serverTimestamp(),
        customInstructions: text,
      });
    await assertSucceeds(user('x'.repeat(2000)));
    await env.clearFirestore();
    await assertFails(user('x'.repeat(2001)));
  });

  test('memories: owner only, up to 500 characters, never edited', async () => {
    const path = 'users/alice/memories/a';
    const memory = (db, text) =>
      setDoc(doc(db, path), { text, createdAt: serverTimestamp() });
    await assertFails(memory(bob(), 'I like tea'));
    await assertFails(memory(alice(), 'x'.repeat(501)));
    await assertSucceeds(memory(alice(), 'I like tea'));
    await assertFails(updateDoc(doc(alice(), path), { text: 'Changed' }));
    await assertSucceeds(deleteDoc(doc(alice(), path)));
  });

  test('projects: notes up to 10,000 characters', async () => {
    const project = (notes) =>
      setDoc(doc(alice(), 'users/alice/projects/p1'), {
        name: 'Exam',
        notes,
        createdAt: serverTimestamp(),
      });
    await assertFails(project('x'.repeat(10001)));
    await assertSucceeds(project('Topics: OSI, TCP'));
  });
});

describe('artifact versions', () => {
  const version = (db, data = {}) =>
    setDoc(doc(db, 'users/alice/conversations/c1/artifacts/v1'), {
      key: 'essay outline',
      title: 'Essay outline',
      kind: 'document',
      content: '# Outline',
      version: 1,
      messageId: 'm1',
      createdAt: serverTimestamp(),
      ...data,
    });

  test('owner can save a version; others cannot', async () => {
    await aliceChat();
    await assertFails(version(bob()));
    await assertSucceeds(version(alice()));
  });

  test('bad kind or huge content is refused; versions never change',
    async () => {
      await aliceChat();
      await assertFails(version(alice(), { kind: 'html' }));
      await assertFails(version(alice(), { content: 'x'.repeat(100001) }));
      await assertSucceeds(version(alice()));
      await assertFails(
        updateDoc(doc(alice(), 'users/alice/conversations/c1/artifacts/v1'), {
          content: 'Changed',
        }),
      );
    });
});

describe('chat titles and the answered flag', () => {
  test('a new chat starts with answered: false', async () => {
    await aliceChat({ answered: false });
  });

  test('the app can mark it answered and rename it', async () => {
    await aliceChat({ answered: false });
    const path = 'users/alice/conversations/c1';
    await assertSucceeds(
      updateDoc(doc(alice(), path), {
        answered: true,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(alice(), path), {
        title: 'Bhutan economy overview',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('answered must be true or false', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/conversations/c1'), {
        title: 'Hello',
        answered: 'yes',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('another user cannot rename it', async () => {
    await aliceChat({ answered: false });
    await assertFails(
      updateDoc(doc(bob(), 'users/alice/conversations/c1'), {
        title: 'Hacked',
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('saved answers', () => {
  const path = 'users/alice/saved/c1_m1';
  const item = (extra = {}) => ({
    conversationId: 'c1',
    messageId: 'm1',
    title: 'Hello',
    preview: 'An answer',
    createdAt: serverTimestamp(),
    ...extra,
  });

  test('the owner can save, read and remove an answer', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), item()));
    await assertSucceeds(getDoc(doc(alice(), path)));
    await assertSucceeds(deleteDoc(doc(alice(), path)));
  });

  test('another user cannot read, save or remove it', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), item()));
    await assertFails(getDoc(doc(bob(), path)));
    await assertFails(deleteDoc(doc(bob(), path)));
    await assertFails(setDoc(doc(bob(), 'users/alice/saved/c1_m2'),
      item({ messageId: 'm2' })));
    await assertFails(getDoc(doc(nobody(), path)));
  });

  test('size limits, wrong id and extra fields are refused', async () => {
    await assertFails(setDoc(doc(alice(), path), item({ preview: 'x'.repeat(501) })));
    await assertFails(setDoc(doc(alice(), path), item({ title: '' })));
    await assertFails(setDoc(doc(alice(), path), item({ text: 'full answer' })));
    await assertFails(setDoc(doc(alice(), 'users/alice/saved/other'), item()));
    await assertFails(
      setDoc(doc(alice(), path), item({ createdAt: new Date('2020-01-01') })),
    );
  });

  test('saved items can never be edited', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), item()));
    await assertFails(updateDoc(doc(alice(), path), { preview: 'Changed' }));
  });
});

describe('feedback on answers', () => {
  const path = 'users/alice/feedback/c1_m2';
  const rating = (extra = {}) => ({
    conversationId: 'c1',
    messageId: 'm2',
    rating: 'up',
    createdAt: serverTimestamp(),
    ...extra,
  });

  test('the owner can rate, change and remove a rating', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), rating()));
    await assertSucceeds(updateDoc(doc(alice(), path), { rating: 'down' }));
    await assertSucceeds(getDoc(doc(alice(), path)));
    await assertSucceeds(deleteDoc(doc(alice(), path)));
  });

  test('another user cannot read, write or remove it', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), rating()));
    await assertFails(getDoc(doc(bob(), path)));
    await assertFails(updateDoc(doc(bob(), path), { rating: 'down' }));
    await assertFails(deleteDoc(doc(bob(), path)));
    await assertFails(setDoc(doc(bob(), 'users/alice/feedback/c1_m3'),
      rating({ messageId: 'm3' })));
    await assertFails(getDoc(doc(nobody(), path)));
  });

  test('only up or down, the right id, and no answer text', async () => {
    await assertFails(setDoc(doc(alice(), path), rating({ rating: 'meh' })));
    await assertFails(setDoc(doc(alice(), 'users/alice/feedback/x'), rating()));
    await assertFails(setDoc(doc(alice(), path), rating({ text: 'answer' })));
  });

  test('only the rating can change', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), rating()));
    await assertFails(updateDoc(doc(alice(), path), { messageId: 'm9' }));
    await assertFails(
      updateDoc(doc(alice(), path), { createdAt: new Date('2020-01-01') }),
    );
  });
});

describe('regenerate and edit (deleting own messages)', () => {
  test('the owner can delete their latest messages', async () => {
    await aliceChat();
    const m = 'users/alice/conversations/c1/messages/m1';
    await assertSucceeds(setDoc(doc(alice(), m),
      { role: 'model', text: 'Hi', createdAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(alice(), m)));
  });

  test('another user cannot delete them', async () => {
    await aliceChat();
    const m = 'users/alice/conversations/c1/messages/m1';
    await assertSucceeds(setDoc(doc(alice(), m),
      { role: 'model', text: 'Hi', createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(bob(), m)));
  });
});

describe('deleting everything (account deletion)', () => {
  test('the owner can delete all their documents', async () => {
    await aliceChat();
    await setDoc(doc(alice(), 'users/alice'), { createdAt: serverTimestamp() });
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/conversations/c1')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
  });
});

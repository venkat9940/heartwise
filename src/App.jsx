
import { useState } from "react";
import "./index.css";

export default function App() {
  const [mode, setMode] = useState("chat");
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState("");
  const [paper, setPaper] = useState("");

  function sendMessage(event) {
    event.preventDefault();

    const text = draft.trim();
    if (!text) return;

    setMessages((previous) => [
      ...previous,
      {
        id: Date.now(),
        text,
      },
    ]);

    setDraft("");
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <div className="brand">
          <span className="logo small">♡</span>
          <div>
            <strong>Heartwise</strong>
            <p>Your shared little world</p>
          </div>
        </div>
      </header>

      <section className="welcome">
        <p className="eyebrow">A LITTLE CLOSER, WHEREVER YOU ARE</p>
        <h1>A space for just the two of you.</h1>
        <p className="muted">
          Write, draw, and connect with someone you love.
        </p>
      </section>

      <section className="panel">
        <h2>Our shared space ♡</h2>

        <nav className="tabs">
          <button
            className={mode === "chat" ? "tab active" : "tab"}
            onClick={() => setMode("chat")}
          >
            Live chat
          </button>

          <button
            className={mode === "paper" ? "tab active" : "tab"}
            onClick={() => setMode("paper")}
          >
            Writing paper
          </button>

          <button
            className={mode === "board" ? "tab active" : "tab"}
            onClick={() => setMode("board")}
          >
            Whiteboard
          </button>
        </nav>

        {mode === "chat" && (
          <div className="chat-area">
            <div className="messages">
              {messages.map((message) => (
                <div className="message mine" key={message.id}>
                  <p>{message.text}</p>
                </div>
              ))}
            </div>

            <form className="composer" onSubmit={sendMessage}>
              <input
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                placeholder="Write from the heart..."
              />

              <button className="primary" type="submit">
                Send
              </button>
            </form>
          </div>
        )}

        {mode === "paper" && (
          <textarea
            className="lined-paper"
            value={paper}
            onChange={(event) => setPaper(event.target.value)}
            placeholder="Dear favorite person..."
          />
        )}

        {mode === "board" && (
          <div className="board-area">
            <p className="muted">
              Your drawing space will appear here.
            </p>
          </div>
        )}
      </section>

      <section className="bottom-grid">
        <article className="panel prompt-card">
          <span className="emoji">💌</span>
          <h3>A question for today</h3>
          <p>What is one little moment with me that made you smile?</p>
          <button
            className="text-button"
            onClick={() => {
              setMode("chat");
              setDraft(
                "What is one little moment with me that made you smile?"
              );
            }}
          >
            Ask your partner →
          </button>
        </article>

        <article className="panel prompt-card">
          <span className="emoji">🌷</span>
          <h3>Make a memory</h3>
          <p>Write something lovely to remember together.</p>
          <button
            className="text-button"
            onClick={() => setMode("paper")}
          >
            Write a memory →
          </button>
        </article>
      </section>
    </main>
  );
}

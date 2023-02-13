from flask import Flask, render_template
app = Flask(__name__, template_folder='.')

visit_count = 0


@app.route("/")
def index():
    global visit_count
    visit_count += 1
    return render_template("index.html", visits=visit_count)


if __name__ == "__main__":
    app.run(debug=True)

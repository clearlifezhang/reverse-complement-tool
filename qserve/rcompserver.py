'''qserve.rcompserver

'''
from flask import Flask, render_template
from markupsafe import escape

app = Flask(__name__)

@app.route('/')
def sequencepage():
    '''Render the HTML response'''
    return render_template(
        'qspage.html',
    )

def rcomp(seq: str) -> str:
    '''Compute the reverse complement of the sequence string

    Args:
        seq: Input DNA sequence string

    Returns:
        Reverse complment DNA sequence or a warning for improperly
        formatted data

    '''
    seq = escape(seq)
    seq_set = set(seq)
    comp_dict = {
        'A': 'T',
        'T': 'A',
        'G': 'C',
        'C': 'G',
        'a': 't',
        't': 'a',
        'g': 'c',
        'c': 'g',
    }
    comp_set = set(comp_dict.keys())
    if not seq_set.issubset(comp_set):
        return f'Warning: seq not a subset of {comp_set}'
    rseq = seq[-1::-1]
    return ''.join(comp_dict[x] for x in rseq)

@app.route("/rcomp/<seq>")
def rcompendpoint(seq):
    # Escape the input string text
    seq = escape(seq)

    # Compute the reverse DNA complement of the string or warning on
    # bad input
    result_str =  rcomp(seq)

    # Return JSON response
    return {'sequence': result_str}


if __name__ == "__main__":
    app.run(host='0.0.0.0')
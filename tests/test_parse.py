def test_parse() -> None:
    """
    Test the parse function from the hl7lite.cython.parse module.
    """
    from hl7lite.cython.parse import parse_batch
    import samples

    hl7_message = samples.ADT_MESSAGE
    parsed_message = parse_batch(hl7_message)
    assert parsed_message.tag == 'batch'
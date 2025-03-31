# distutils: include_dirs = LXML_PACKAGE_DIR
# cython: language_level=3
# cython: profile=True
# cython: linetrace=True

cimport cython
cimport lxml.includes.etreepublic as cetree

cdef object etree
from lxml import etree

cetree.import_lxml__etree()


def parse_batch(s: str):
    """Parse HL7 message to lxml ElementTree."""
    text_length: cython.ulong = len(s)

    # States
    i: cython.ulong = 0
    j: cython.ulong = 0
    char: str
    end_of_line: cython.bint = True
    escape_char_active: cython.bint = False

    # Escape sequences
    field_separator: str
    component_separator: str
    subcomponent_separator: str
    repetition_separator: str
    escape_character: str
    truncation_character: str

    # Result objects
    root: etree._Element = etree.Element("batch")
    current_node: etree._Element = root
    _new_node: etree._Element

    while i < text_length:
        # At start or after end_of_line
        if s[i] == '\r':
            end_of_line = True
            i += 1
            continue

        # Check for "MSH"
        if end_of_line and (i+3<text_length) and s[i:i+3]=='MSH':
            # Update state
            end_of_line = False
            
            # Create the message element base
            current_node = root.makeelement("message")
            root.append(current_node)
            
            # Create the segment element
            _new_node = current_node.makeelement("segment", attrib={"type": "MSH"})
            current_node.append(_new_node)
            current_node = _new_node
            
            # Extract the delimiters for the message
            field_separator = '|'
            component_separator = '^'
            repetition_separator = '~'
            escape_character = "\\"
            subcomponent_separator = '&'
            truncation_character = "" # Only set if defined
            i = i + 3
            j = 0
            while i+j<text_length:
                char = s[i+j]
                if j > 0 and char == field_separator:
                    break

                if j==0:
                    field_separator = char
                elif j==1:
                    component_separator = char
                elif j==2:
                    repetition_separator = char
                elif j==3:
                    escape_character = char
                elif j==4:
                    subcomponent_separator = char
                elif j==5:
                    truncation_character = char

                j += 1

            # Move i past the delimiters
            i=i+j+1

            # Add fields for the delimiters
            current_node.append(current_node.makeelement(
                "MSH.1",
                index="1",
                type=field_separator,
            ))

            current_node.append(current_node.makeelement(
                "MSH.2",
                text=(
                    component_separator
                    + subcomponent_separator
                    + repetition_separator
                    + escape_character
                    + truncation_character
                ),
                attrib={"type": "encoding_characters", "index": "2"},
            ))
            continue

        i += 1
        end_of_line = False

    return root

# distutils: include_dirs = LXML_PACKAGE_DIR
# cython: language_level=3
# cython: profile=True
# cython: linetrace=True

from __future__ import print_function

cimport lxml.includes.etreepublic as cetree
from lxml.includes.etreepublic cimport _Element, makeSubElement

from lxml import etree

cetree.import_lxml__etree()

cdef enum _Hl7Level:
    BATCH = 0
    MESSAGE = 1
    SEGMENT = 2
    FIELD = 3
    COMPONENT = 4
    SUBCOMPONENT = 5



cdef _Element _parse(str s):
    # Convert the string to a bytearray
    cdef bytes ascii_str = s.encode('ascii')
    cdef const unsigned char[:] c_str = bytearray(ascii_str)
    cdef unsigned long length = len(ascii_str)

    # New line character
    cdef unsigned char new_line_char = b'\r'

    # Delimiters
    cdef unsigned char field_separator
    cdef unsigned char component_separator
    cdef unsigned char repetition_separator
    cdef unsigned char escape_character
    cdef unsigned char subcomponent_separator

    # Indexing
    cdef unsigned long i = 0
    cdef unsigned long j = 0

    # Reached end of loop without finding a new segment
    cdef bint reached_end = False

    # Index tracking
    cdef unsigned long field_index = 1
    cdef unsigned long component_index = 1
    cdef unsigned long subcomponent_index = 1

    # Has the message been escaped
    cdef bint escaped = False

    # True at the start or after a new line character
    cdef bint new_segment = True

    cdef _Element batch = etree.Element("batch")
    cdef _Element element = batch
    cdef _Hl7Level level = _Hl7Level.BATCH

    while j < length:
        # Check for an escape character
        if not escaped and c_str[j] == escape_character:
            escaped = True
            j += 1
            continue
        elif escaped:
            escaped = False
            j += 1
            continue 
        
        # Check for a new line character 
        if c_str[j] == new_line_char:
            if level == _Hl7Level.SEGMENT:
                element = makeSubElement(element, tag="field", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
            elif level == _Hl7Level.FIELD:
                element = makeSubElement(element.getparent(), tag="field", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
            elif level == _Hl7Level.COMPONENT:
                element = makeSubElement(element.getparent(), tag="component", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
            elif level == _Hl7Level.SUBCOMPONENT:
                element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)

            new_segment = True
            j += 1
            i = j # Skip the new line character
            continue

        # Create Segment
        if new_segment is True:
            new_segment = False
            i = j # catchup to start of potential segment

            # Check first 3 characters are MSH
            if c_str[i:i+3] == bytearray(b'MSH'):
                field_separator = c_str[i+3]
                component_separator = c_str[i+4]
                repetition_separator = c_str[i+5]
                escape_character = c_str[i+6]
                subcomponent_separator = c_str[i+7]
                if c_str[i+8] != field_separator:
                    raise NotImplementedError("MSH subcomponent is not followed by a field separator: " + bytes(c_str[i:i+9]).decode('ascii'))

                element = makeSubElement(batch, tag="message", text=None, tail=None, attrib=None, nsmap=None)
                element = makeSubElement(element, tag="segment", text=None, tail=None, attrib={"type": "MSH"}, nsmap=None)
                element = makeSubElement(element, tag="field", text=bytearray(c_str[i+3:i+4]), tail=None, attrib={"index": "1"}, nsmap=None)
                element = makeSubElement(element.getparent(), tag="field", text=bytearray(c_str[i+4:i+8]), tail=None, attrib={"index": "2"}, nsmap=None)
                level = _Hl7Level.FIELD
                field_index = 3
                i = i + 9 # Skip the field separator
                j = i
                continue
            
            # For other message types, we need to find the next field separator
            reached_end = False
            while j < length or c_str[j] == new_line_char:
                if c_str[j] == field_separator:
                    reached_end = True
                    break
                
                j += 1

            # This could be triggered at the end of a line or at the end of the file
            if reached_end is False:
                i = j
                continue # Let the next iteration clean up

            # Create the message and segment elements
            if level == _Hl7Level.MESSAGE:
                pass
            elif level == _Hl7Level.SEGMENT:
                element = element.getparent()
            elif level == _Hl7Level.FIELD:
                element = element.getparent().getparent()
            elif level == _Hl7Level.COMPONENT:
                element = element.getparent().getparent().getparent()

            element = makeSubElement(element, tag="segment", text=None, tail=None, attrib={"type": bytearray(c_str[i:j])}, nsmap=None)

            level = _Hl7Level.SEGMENT
            j += 1 # Skip the field separator
            i = j
            continue

        # Field end
        if field_separator is not None and c_str[j] == field_separator:
            if level == _Hl7Level.SEGMENT:
                field_index = 1
                element = makeSubElement(element, tag="field", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
            elif level == _Hl7Level.FIELD:
                element = makeSubElement(element.getparent(), tag="field", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
            elif level == _Hl7Level.COMPONENT:
                element = makeSubElement(element.getparent(), tag="component", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
                element = element.getparent()
            elif level == _Hl7Level.SUBCOMPONENT:
                element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)
                element = element.getparent().getparent()
                
            field_index += 1
            level = _Hl7Level.FIELD
            j += 1 # Skip the field separator
            i = j
            continue

        # Component end
        if component_separator is not None and c_str[j] == component_separator:
            if level == _Hl7Level.SEGMENT:
                raise NotImplementedError("Component separator found at the start of a segment")
            elif level == _Hl7Level.FIELD:
                component_index = 1
                element = makeSubElement(element.getparent(), tag="field", text=None, tail=None, attrib={"index": str(field_index)}, nsmap=None)
                element = makeSubElement(element, tag="component", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
            elif level == _Hl7Level.COMPONENT:
                element = makeSubElement(element.getparent(), tag="component", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
            elif level == _Hl7Level.SUBCOMPONENT:
                element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)
                element = element.getparent()

            component_index += 1
            level = _Hl7Level.COMPONENT
            j += 1
            i = j
            continue

        # Subcomponent end
        if subcomponent_separator is not None and c_str[j] == subcomponent_separator:
            if level == _Hl7Level.SEGMENT:
                raise NotImplementedError("Subcomponent separator found at the start of a segment")
            elif level == _Hl7Level.FIELD:
                component_index = 1
                subcomponent_index = 1
                element = makeSubElement(element.getparent(), tag="field", text=None, tail=None, attrib={"index": str(field_index)}, nsmap=None)
                element = makeSubElement(element, tag="component", text=None, tail=None, attrib={"index": str(component_index)}, nsmap=None)
                element = makeSubElement(element, tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)
            elif level == _Hl7Level.COMPONENT:
                subcomponent_index = 1
                element = makeSubElement(element.getparent(), tag="component", text=None, tail=None, attrib={"index": str(component_index)}, nsmap=None)
                element = makeSubElement(element, tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)
            elif level == _Hl7Level.SUBCOMPONENT:
                element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)

            subcomponent_index += 1
            level = _Hl7Level.SUBCOMPONENT
            j += 1
            i = j
            continue

        if repetition_separator is not None and c_str[j] == repetition_separator:
            if level == _Hl7Level.SEGMENT:
                raise NotImplementedError("Repetition separator found at the start of a segment")
            elif level == _Hl7Level.FIELD:
                element = makeSubElement(element.getparent(), tag="field", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
            elif level == _Hl7Level.COMPONENT:
                element = makeSubElement(element.getparent(), tag="component", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
                element = element.getparent()
            elif level == _Hl7Level.SUBCOMPONENT:
                element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:j]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)
                element = element.getparent().getparent()

            # Does not increment the field index
            level = _Hl7Level.FIELD
            j += 1
            i = j

        j += 1

    # TODO: Add the last element
    if i == length:
        pass
    elif level == _Hl7Level.SEGMENT:
        element = makeSubElement(element, tag="field", text=bytearray(c_str[i:length]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
    elif level == _Hl7Level.FIELD:
        element = makeSubElement(element.getparent(), tag="field", text=bytearray(c_str[i:length]), tail=None, attrib={"index": str(field_index)}, nsmap=None)
    elif level == _Hl7Level.COMPONENT:
        element = makeSubElement(element.getparent(), tag="component", text=bytearray(c_str[i:length]), tail=None, attrib={"index": str(component_index)}, nsmap=None)
    elif level == _Hl7Level.SUBCOMPONENT:
        element = makeSubElement(element.getparent(), tag="subcomponent", text=bytearray(c_str[i:length]), tail=None, attrib={"index": str(subcomponent_index)}, nsmap=None)

    return batch

cpdef _Element parse(str s):
    return _parse(s)
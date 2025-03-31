import pyximport
pyximport.install()

import line_profiler
from hl7lite.cython.parse import parse_batch


message = r"""
MSH|^~\&|SendingApp|SendingFacility|ReceivingApp|ReceivingFacility|20250329103000||ADT^A01|123456|P|2.5.1
EVN|A01|20250329103000|||CLERK01
PID|1||123456^^^HospitalMRN^MR||Doe^John^A||19800101|M|||123 Main St^^Metropolis^NY^10001^USA||(555)555-1234|||EN^English|S|123456789|987-65-4321
NK1|1|Doe^Jane|SPO|123 Main St^^Metropolis^NY^10001^USA|(555)555-5678
NK1|2|Smith^Jane|SPO|456 Elm St^^Metropolis^NY^10001^USA|(555)555-8765
PV1|1|I|2000^2012^01||||1234^Smith^Jane^MD|||||||||||1234567||||||||||||||||||||||||20250329103000
GT1|1|Doe^John^A|123456^^^HospitalMRN^MR|20250329103000|20250329103000
GT1|2|Doe^Jane|123456^^^HospitalMRN^MR|20250329103000|20250329103000
AL1|1||^Allergy^Code^System|^Allergy^Type^Code|^Allergy^Severity^Code|20250329103000
AL1|2||^Allergy^Code^System|^Allergy^Type^Code|^Allergy^Severity^Code|20250329103000
DG1|1||123456^Diagnosis^Code^System|^Diagnosis^Type^Code|^Diagnosis^Severity^Code|20250329103000
"""

def message_generator(n: int) -> str:
    return message.replace('\n', '\r') * n

m = message_generator(100000)

func = parse_batch
profile = line_profiler.LineProfiler()
profile.add_function(func)
# profile.add_function(func.__code__)
profile.runcall(func, m)
profile.print_stats()
profile.dump_stats('hl7lite.cython.parse_batch.lprof')

result = func(m)
print(len(result.xpath('/batch/message')))
# Monte Carlo simulation of the Shor's algorithm 

using QuantumClifford
using Plots

# Stabilizer Tableau 
code_shor9 = S"ZZIIIIIII
               IZZIIIIII
               IIIZZIIII
               IIIIZZIII
               IIIIIIZZI
               IIIIIIIZZ
               XXXXXXIII
               IIIXXXXXX"

"""Generate a lookup table for decoding single qubit errors. Maps s → ē."""
function create_lookup_table(code::Stabilizer)
     lookup_table = Dict()
     constraints, qubits = size(code)
     # In the case of no errors
     lookup_table[zeros(UInt8, constraints)] = zero(PauliOperator, qubits)
     # In the case of single bit errors
     for bit_to_be_flipped in 1:qubits
          for error_type in [single_x, single_y, single_z]
               # Generate ē
               error = error_type(qubits, bit_to_be_flipped)
               # Calculate s (syndrome)
               syndrome = comm(error, code)
               # Store s → ē
               lookup_table[syndrome] = error
          end
     end
     lookup_table
end;

# ************** MONTE CARLO SIMULATION **************
# """For a given physical bit-flip error rate, parity check matrix, and a lookup table,
# estimate logical error rate, assuming non-degenerate code."""
# """For a given physical bit-flip error rate, parity check matrix, and a lookup table,
# estimate logical error rate, taking into account the code might be degenerate."""
function evaluate_degen_code_decoder(code::Stabilizer, lookup_table, p; samples=10_000)
     constraints, qubits = size(code)
     full_tableau = MixedDestabilizer(code)
     logicals = vcat(logicalxview(full_tableau), logicalzview(full_tableau))
     decoded = 0  # Counts correct decodings
     for sample in 1:samples
          # Generate random error
          error = random_pauli(qubits, p / 3, nophase=true)
          # Apply that error to your physical system
          # and get syndrome
          syndrome = comm(error, code)
          # Decode the syndrome
          guess = get(lookup_table, syndrome, nothing)
          # Check if the suggested error correction
          # corrects the error or if it is equivalent
          # to a logical operation
          if !isnothing(guess) && all(==(0x0), comm(guess * error, code)) && all(==(0x0), comm(guess * error, logicals))
               decoded += 1
          end
     end
     1 - decoded / samples
end


# Plotting function
function plot_code_performance(phys, logical; title="Code performance")
     # 1) plot the physical-error diagonal y = x
     p = plot(
          phys,                # x data
          phys,                # y = x
          label="single bit",
          linestyle=:dash,
          xlabel="Physical (qubit) error rate",
          ylabel="Logical error rate",
          title=title,
          legend=:topleft,
          ylims=(0.0, 0.13),
          xlims=(0.0, 0.09),
     )

     # 2) overlay the simulated logical-error points
     scatter!(
          p,
          phys,
          logical;
          label="after decoding",
          marker=(:circle, 6),
     )

     return p
end

Shor9_table = create_lookup_table(code_shor9)

# 1. Define a range of physical bit-flip error rates (from 0.0 to 0.09 in steps of 0.005)
error_rates = 0.0:0.005:0.09

# 2. For each physical error rate p, estimate the Steane code’s logical error rate
#    using a Monte Carlo decoder.  Time the whole comprehension.
@time post_ec_error_rates = [
     evaluate_degen_code_decoder(code_shor9, Shor9_table, p; samples=100_000)
     for p in error_rates
]

# 3. Plot physical vs. logical error rates for the Steane code
plot_code_performance(
     error_rates,
     post_ec_error_rates;
     title="Shor quantum code"
)


